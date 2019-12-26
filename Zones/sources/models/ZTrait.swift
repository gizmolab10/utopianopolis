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
    case eDuration  = "+" // accumulative
	case eEmail     = "e"
	case eEssay     = "w"
    case eGraphic   = "g"
    case eHyperlink = "h"
    case eMoney     = "$" // accumulative
    case eTime      = "t"

	var extraHeight: CGFloat {
		switch self {
			case .eHyperlink,
				 .eMoney: return 1.0
			case .eTime:  return 0.8
			default: 	  return 0.66667
		}
	}
}


class ZTrait: ZRecord {

    
	@objc dynamic var format: String?
    @objc dynamic var   type: String?
	@objc dynamic var   text: String?
    @objc dynamic var   data: Data?
    @objc dynamic var  asset: CKAsset?
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
				case .eEmail: return "email address"
				case .eEssay: return "write"
				case .eHyperlink: return "hyperlink"
				default: break
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
               #keyPath(data),
               #keyPath(text),
			   #keyPath(owner),
			   #keyPath(asset),
			   #keyPath(format)]
    }


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + ZTrait.cloudProperties()
    }


    override func orphan() {
        ownerZone?.setTraitText(nil, for: traitType)

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

			if  let     s = text {
				string    = NSMutableAttributedString(string: s)

				if  let a = format {
					string?.attributesAsString = a
				}
			}

			return string
		}

		set {
			if  let string = newValue {
				format 	   = string.attributesAsString
				text 	   = string.string
			}
		}
	}

}
