//
//  ZTrait.swift
//  Seriously
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

enum ZTraitType: String {
	case tDuration  = "+" // accumulative
	case tMoney     = "$" //      "
	case tAssets    = "a" // allow multiple
	case tHyperlink = "h"
	case tEmail     = "e"
	case tEssay     = "w"
	case tDate      = "d"
	case tNote      = "n"

	var heightRatio: CGFloat {
		switch self {
			case .tHyperlink,
				 .tMoney,
				 .tDate: return 1.0
			default:     return 0.66667
		}
	}

	var description: String? {
		switch self {
			case .tHyperlink: return "LINK"
			case .tEmail:     return "EMAIL"
			case .tEssay:     return "ESSAY"
			case .tNote:      return "NOTE"
			default:          return nil
		}
	}

}

class ZTrait: ZRecord {

	@objc dynamic var      owner :  CKRecord.Reference?
	@objc dynamic var     assets : [CKAsset]?
	@objc dynamic var    strings : [String]?
	@objc dynamic var assetNames :  String?
	@objc dynamic var     format :  String?
	@objc dynamic var       type :  String?
	@objc dynamic var       text :  String?   { didSet { updateSearchableStrings() } }
    override var   unwrappedName :  String    { return text ?? emptyName }
 	var               _traitType :  ZTraitType?
	var               _ownerZone :  Zone?

	// MARK:- text
	// MARK:-

	var noteText: NSMutableAttributedString? {
		get {
			var        string : NSMutableAttributedString?
			let       isEmpty = text == nil || text!.isEmpty || text! == kEssayDefault

			setCurrentTrait {
				if  isEmpty {
					text      = kEssayDefault
				}

				if  let     s = text {
					string    = NSMutableAttributedString(string: s)

					if  let f = format {
						string?.attributesAsString = f
					} else if isEmpty {
						string?.addAttribute(.font, value: gDefaultEssayFont, range: NSRange(location: 0, length: text!.length))
					}
				}
			}

			return string
		}

		set {
			setCurrentTrait {
				if  let string = newValue {
					text 	   = string.string
					format 	   = string.attributesAsString

					// THE NEXT STATEMENT, and one in prepareForNewDesign
					// ARE THE ONLY code which gathers assets for images,
					// side-effect for a dropped image:
					// it creates and adds an asset

					assets     = string.assets(for: self)

					updateCKRecordProperties()
				}
			}
		}
	}

    var deepCopy: ZTrait {
        let theCopy = ZTrait(databaseID: databaseID)

        copy(into: theCopy)

        return theCopy
    }

    override var emptyName: String {
        if  let tType = traitType {
            switch tType {
				case .tEmail:     return "email address"
				case .tHyperlink: return "hyperlink"
				default:          break
            }
        }

        return ""
    }

    var traitType: ZTraitType? {
        get {
            if  _traitType == nil, type != nil {
                _traitType  = ZTraitType(rawValue: type!)
            }

            return _traitType
        }

        set {
            if newValue != _traitType {
                _traitType = newValue
                type       = newValue?.rawValue
            }
        }
    }

    var ownerZone: Zone? {
        if  _ownerZone == nil {
            _ownerZone  = gRemoteStorage.maybeZoneForRecordName(owner?.recordID.recordName)
        }

        return _ownerZone
    }

	func setCurrentTrait(during: Closure) {
		let     prior = gCurrentTrait // can be called within recursive traversal of notes within notes, etc.
		gCurrentTrait = self
		during()
		gCurrentTrait = prior
	}

    convenience init(databaseID: ZDatabaseID?) {
        self.init(record: CKRecord(recordType: kTraitType), databaseID: databaseID)
    }

    convenience init(dict: ZStorageDictionary, in dbID: ZDatabaseID) {
        self.init(record: nil, databaseID: dbID)

        extractFromStorageDictionary(dict, of: kTraitType, into: dbID)
    }

    override class func cloudProperties() -> [String] {
        return[#keyPath(type),
               #keyPath(text),
			   #keyPath(owner),
			   #keyPath(format),
			   #keyPath(assets),
			   #keyPath(strings),
			   #keyPath(assetNames)]
    }

    override func cloudProperties() -> [String] {
        return super.cloudProperties() + ZTrait.cloudProperties()
    }

    override func orphan() {
        ownerZone?.setTraitText(nil, for: traitType)

        owner = nil

        updateCKRecordProperties()
    }

	override var isAdoptable: Bool { return owner != nil }

	override func adopt(moveOrphansToLost: Bool = false) {
        if  let o = ownerZone, let traits = ownerZone?.traits, let t = traitType, traits[t] == nil {
            o.maybeMarkNotFetched()
			removeState(.needsAdoption)

            o.traits[t] = self
		} else if moveOrphansToLost, let r = record, !r.isOrphaned {
			removeState(.needsAdoption)
        }
    }

	func updateSearchableStrings() {
		let searchables: [ZTraitType] = [.tNote, .tEssay, .tEmail, .tHyperlink]

		if  let  tt = traitType, searchables.contains(tt) {
			strings = text?.searchable.components(separatedBy: kSpace)
		}
	}

	func updateEssayFontSize(_ increment: Bool) -> Bool {
		var updated       = false

		if  let f         = format {
			let separator = "NSFontSizeAttribute (f) "
			var parts     = f.components(separatedBy: separator)

			for (index, part) in parts.enumerated() {
				if  index              != 0 {
					let subSeparator    = kColonSeparator
					var subParts        = part.components(separatedBy: subSeparator)
					let number          = subParts[0]

					if  var value       = number.integerValue {
						value          += (increment ? 1 : -1) * 6

						if  value      >= 12 { 	    // minimum font size is 12
							subParts[0] = "\(value)"
							updated     = true
						}
					}

					parts[index]        = subParts.joined(separator: subSeparator)
				}
			}

			format = parts.joined(separator: separator)
		}

		return updated
	}

	// MARK:- image support
	// MARK:-

	// ONLY called within noteText set
	//
	// check if file actually exist in assets folder
	// by successfully creating a wrapper
	// try using the filename passed in
	// then look up the the corresponding ASSET and try using ITS fileurl
	// if either exists, create a text attachment from the wrapper

	func textAttachment(for fileName: String) -> NSTextAttachment? {
		var     url = gFiles.imageURLInAssetsFolder(for: fileName)
		var  attach : NSTextAttachment?
		var wrapper : FileWrapper?

		let grabWrapper = {
			do {
				wrapper = try FileWrapper(url: url, options: [])
			} catch {}
		}

		grabWrapper()

		if  wrapper  == nil,
			let asset = assetFromAssetNamesForName(fileName) {
			url       = asset.fileURL

			grabWrapper()
		}

		if  let  w = wrapper {
			attach = NSTextAttachment(fileWrapper: w)
		} else {
			printDebug(.dImages, "DETACH  \(url)")
		}

		return attach
	}

	func createAssetFromImage(_ image: ZImage, for fileName: String) -> CKAsset? {
		if  let     asset = assetFromAssetNamesForName(fileName) {
			return  asset
		} else if let url = writeImageIntoAssetsFolder(image, using: fileName) {
			let     asset = CKAsset(fileURL: url)    // side-effect creates asset for dropped image

			if  appendUniquelyToAssetNames(fileName, with: asset) {
				needSave()
			}

			return asset
		}

		return nil
	}

	func appendUniquelyToAssetNames(_ imageName: String, with asset: CKAsset) -> Bool {
		if  var     names = assetNames?.componentsSeparatedAt(level: 0),
			let  checksum = asset.data?.checksum {
			let separator = gSeparatorAt(level: 1)
			let assetName = imageName + separator + "\(checksum)"

			if !names.contains(assetName) {
				for (index, name) in names.enumerated() {
					let parts = name.componentsSeparatedAt(level: 1)

					if  parts.count > 1,
						parts[0] == imageName {
						names.remove(at: index)     // remove duplicate imageName and uuid

						break
					}
				}

				names.append(assetName)				// add imageName and asset's uuid
				printDebug(.dImages, "APPEND  \(assetName)")

				assetNames = names.joined(separator: gSeparatorAt(level: 0))

				return true
			}
		}

		return false
	}

	func assetFromAssetNamesForName(_ name: String) -> CKAsset? {
		if  let items = assetNames?.componentsSeparatedAt(level: 0),
			let array = assets,
			array.count > 0 {
			for item in items {
				let parts = item.componentsSeparatedAt(level: 1)

				if  parts.count == 2,
					name == parts[0],
					let checksum = parts[1].integerValue {

					for asset in array {
						if  asset.data?.checksum == checksum {
							return asset
						}
					}
				}
			}
		}

		return nil
	}

	private func writeImageIntoAssetsFolder(_ image: ZImage, using originalName: String? = nil) -> URL? {
		if  let name = originalName {
			let url = gFiles.imageURLInAssetsFolder(for: name)

			if  url.writeImage(image) {
				return url
			}
		}

		// check if file exists at url

		return nil
	}

	func prepareForNewDesign() {
		var   zoneName = "unowned"
		var     update = false

		if  let      o = ownerZone {
			zoneName   = "\(o)"
		}

		if  let  names = assetNames, names.length > 0 {
			let  parts = names.componentsSeparatedAt(level: 0)
			assetNames = ""

			for part in parts {
				let subparts = part.componentsSeparatedAt(level: 1)

				if  subparts.count != 3 {
					assetNames?.append(part)
				} else if let array = assets,
					let    checksum = subparts[2].integerValue {
					update          = true

					for (index, asset) in array.enumerated() {
						if  let c = asset.data?.checksum, c == checksum {
							assets?.remove(at: index)

							break
						}
					}
				}
			}
		}

		if  assets    != nil && assets!.count != 0 && noteText?.assets(for: self) == nil && (assetNames == nil || assetNames!.length == 0) {
			assets     = []
			assetNames = ""
			update     = true
		}

		if  update {
			needSave()
			printDebug(.dImages, "UPDATE  \(zoneName)")
		}
	}

}
