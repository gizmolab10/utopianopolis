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

@objc(ZTrait)
class ZTrait: ZTraitAssets {

	@objc dynamic var    owner :  CKRecord.Reference?
	@objc dynamic var  strings : [String]?
	@objc dynamic var   format :  String?
	@objc dynamic var     type :  String?
	@objc dynamic var     text :  String? { didSet { updateSearchables() } }
    override var unwrappedName :  String  { return text ?? emptyName }
	var             _ownerZone :  Zone?
	var             _traitType :  ZTraitType?

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

					// THE NEXT STATEMENT IS THE ONLY code which gathers assets for images,
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

    convenience init(dict: ZStorageDictionary, in dbID: ZDatabaseID) throws {
        self.init(record: nil, databaseID: dbID)

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

    override func orphan() {
        ownerZone?.setTraitText(nil, for: traitType)

        owner = nil

        updateCKRecordProperties()
    }

	override var isAdoptable: Bool { return owner != nil }

	override func adopt(forceAdoption: Bool = true, moveOrphansToLost: Bool = false) {
        if  let o = ownerZone, let traits = ownerZone?.traits, let t = traitType, traits[t] == nil {
            o.maybeMarkNotFetched()
			removeState(.needsAdoption)

            o.traits[t] = self
		} else if moveOrphansToLost, let r = record, !r.isOrphaned {
			removeState(.needsAdoption)
        }
    }

	func updateSearchables() {
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

}
