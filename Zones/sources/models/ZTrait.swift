//
//  ZTrait.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

enum ZTraitType: String {
	case eDate      = "d"
	case eHyperlink = "h"
	case eDuration  = "+" // accumulative
	case eMoney     = "$" //      "
	case eAsset     = "a" // allow multiple
	case eEmail     = "e"
	case eEssay     = "w"

	var heightRatio: CGFloat {
		switch self {
			case .eDuration,
				 .eEmail,
				 .eEssay: return 0.66667
			default: 	  return 1.0
		}
	}
}

class ZTrait: ZRecord {

	@objc dynamic var format: String?
    @objc dynamic var   type: String?
	@objc dynamic var   text: String?
	@objc dynamic var  asset: CKAsset?
	@objc dynamic var offset: NSNumber?
    @objc dynamic var  owner: CKRecord.Reference?
    var _traitType: ZTraitType?
    var _ownerZone: Zone?
    override var unwrappedName: String { return text ?? emptyName }

    var deepCopy: ZTrait {
        let theCopy = ZTrait(databaseID: databaseID)

        copy(into: theCopy)

        return theCopy
    }

    override var emptyName: String {
        if  let tType = traitType {
            switch tType {
				case .eEmail:     return "email address"
				case .eHyperlink: return "hyperlink"
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
            _ownerZone  = cloud?.maybeZoneForRecordID(owner?.recordID)
        }

        return _ownerZone
    }

    convenience init(databaseID: ZDatabaseID?) {
        self.init(record: CKRecord(recordType: kTraitType), databaseID: databaseID)
    }

    convenience init(dict: ZStorageDictionary, in dbID: ZDatabaseID) {
        self.init(record: nil, databaseID: dbID)

        setStorageDictionary(dict, of: kTraitType, into: dbID)
    }

    override class func cloudProperties() -> [String] {
        return[#keyPath(type),
               #keyPath(text),
			   #keyPath(owner),
			   #keyPath(asset),
			   #keyPath(offset),
			   #keyPath(format)]
    }

    override func cloudProperties() -> [String] {
        return super.cloudProperties() + ZTrait.cloudProperties()
    }

    override func orphan() {
        ownerZone?.setTextTrait(nil, for: traitType)

        owner = nil

        updateCKRecordProperties()
    }

    override func unorphan() {
        if  let traits = ownerZone?.traits, let t = traitType, traits[t] == nil {
            ownerZone?.maybeMarkNotFetched()

            ownerZone?.traits[t] = self
        } else {
            needUnorphan()
        }
    }

	var essayText: NSMutableAttributedString? {
		get {
			var string: NSMutableAttributedString?
			let isEmpty   = text == nil || text!.isEmpty

			if  text     == nil {
				text      = kEssayDefault
			}

			if  let     s = text {
				string    = NSMutableAttributedString(string: s)

				if  let a = format {
					string?.attributesAsString = a
				} else if isEmpty {
					string?.addAttribute(.font, value: gDefaultEssayFont, range: NSRange(location: 0, length: text!.length))
				}
			}

			return string
		}

		set {
			if  let string = newValue {
				format 	   = string.attributesAsString
				asset      = string.image?.jpeg?.asset
				text 	   = string.string
			}
		}
	}

	func updateEssayFontSize(_ increment: Bool) -> Bool {
		var updated       = false

		if  let f         = format {
			let separator = "NSFontSizeAttribute (f) "
			var parts     = f.components(separatedBy: separator)

			for (index, part) in parts.enumerated() {
				if  index              != 0 {
					let subSeparator    = kSeparator
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
