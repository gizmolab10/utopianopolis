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
	case tVideo     = "v"
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
			case .tVideo:     return "VIDEO"
			case .tNote:      return "NOTE"
			default:          return nil
		}
	}

}

@objc(ZTrait)
class ZTrait: ZTraitAssets {

	@NSManaged    var    owner :  CKReference?
	@NSManaged    var  strings : [String]?
	@NSManaged    var   format :  String?
	@NSManaged    var     type :  String?
	@NSManaged    var     text :  String?
    override var unwrappedName :  String  { return text ?? emptyName }
	var             _ownerZone :  Zone?
	var             _traitType :  ZTraitType?

	// MARK:- initialize
	// MARK:-

	func deepCopy(dbID: ZDatabaseID?) -> ZTrait {
		let theRecord = CKRecord(recordType: kTraitType)
		let theCopy   = ZTrait.create(record: theRecord, databaseID: dbID)

		copyIntoZRecord(theCopy)
		theCopy.maybeNeedSave() // so KVO won't set needsMerge

		return theCopy
	}

	static func createAsync(record: CKRecord, databaseID: ZDatabaseID?, onCreation: @escaping ZTraitClosure) {
		hasMaybeAsync(record: record, entityName: kTraitType, databaseID: databaseID) { zRecord in           // first check if already exists
			onCreation(zRecord as? ZTrait ?? ZTrait(record: record, databaseID: databaseID))
		}
	}

	static func create(record: CKRecord, databaseID: ZDatabaseID?) -> ZTrait {
		return hasMaybe(record: record, entityName: kTraitType, databaseID: databaseID) as? ZTrait ??        // first check if already exists
			ZTrait(record: record, entityName: kTraitType, databaseID: databaseID)
	}

	convenience init(databaseID: ZDatabaseID?) {
		self.init(record: CKRecord(recordType: kTraitType), databaseID: databaseID)
	}

	convenience init(dict: ZStorageDictionary, in dbID: ZDatabaseID) throws {
		self.init(entityName: kTraitType, databaseID: dbID)

		try extractFromStorageDictionary(dict, of: kTraitType, into: dbID)
	}

	override var cloudProperties: [String] { return ZTrait.cloudProperties }
	override var optionalCloudProperties: [String] { return ZTrait.optionalCloudProperties }

	override class var cloudProperties: [String] {
		return [#keyPath(type),
				#keyPath(text),
				#keyPath(strings)] +
			optionalCloudProperties +
			super.cloudProperties
	}

	override class var optionalCloudProperties: [String] {
		return [#keyPath(owner),
				#keyPath(format)] +
			super.optionalCloudProperties
	}

	// MARK:- text
	// MARK:-

	var noteText: NSMutableAttributedString? {
		get {
			var        string : NSMutableAttributedString?
			let       isEmpty = text == nil || text!.isEmpty || text! == kEssayDefault

			setCurrentTrait {
				if  isEmpty {
					text      = kEssayDefault

					updateSearchables()
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

					if  text?.isEmpty ?? true {
						text = kEssayDefault
					}

					// THE NEXT STATEMENT IS THE ONLY code which gathers assets for images,
					// side-effect for each dropped image:
					// it creates and adds an asset and a ZFile

					extractAssets(from: string)
					updateSearchables()
					updateCKRecordProperties()
				}
			}
		}
	}

    override var emptyName: String {
        if  let tType = traitType {
            switch tType {
				case .tVideo:     return "video file name"
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

    override func orphan() {
        ownerZone?.setTraitText(nil, for: traitType)

        owner = nil

        updateCKRecordProperties()
    }

	override var isAdoptable: Bool { return owner != nil }

	override func adopt(recursively: Bool = false) {
        if  let      o = ownerZone,
			let traits = ownerZone?.traits,
			let      t = traitType, traits[t] == nil {
            o.maybeMarkNotFetched()
			removeState(.needsAdoption)

			o.addTrait(self)
        }
    }

	func updateSearchables() {
		let searchables: [ZTraitType] = [.tNote, .tEssay, .tEmail, .tVideo, .tHyperlink]

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

}
