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
	case tDuration  = "+" // accumulative
	case tMoney     = "$" //      "
	case tAsset     = "a" // allow multiple
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

	@objc dynamic var strings: [String]?
	@objc dynamic var  format:  String?
    @objc dynamic var    type:  String?
	@objc dynamic var    text:  String? { didSet { updateSearchableStrings() } }
	@objc dynamic var   asset:  CKAsset?
	@objc dynamic var  assets: [CKAsset]?
	@objc dynamic var  offset:  NSNumber?
    @objc dynamic var   owner:  CKRecord.Reference?
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
			   #keyPath(assets),
			   #keyPath(offset),
			   #keyPath(format),
			   #keyPath(strings)]
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

	func updateSearchableStrings() {
		let searchables: [ZTraitType] = [.tNote, .tEssay, .tEmail, .tHyperlink]

		if  let  tt = traitType, searchables.contains(tt) {
			strings = text?.searchable.components(separatedBy: " ")
		}
	}

	var noteText: NSMutableAttributedString? {
		get {
			var string: NSMutableAttributedString?
			let isEmpty   = text == nil || text!.isEmpty || text! == kEssayDefault

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
				assets     = string.assets
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
