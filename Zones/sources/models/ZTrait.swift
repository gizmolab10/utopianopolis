//
//  ZTrait.swift
//  Zones
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


enum ZTraitType: String {
    case eComposition = "c"
    case eDuration    = "d" // accumulative
    case eEmail       = "e"
    case eGraphic     = "g"
    case eHyperlink   = "h"
    case eMoney       = "m" // accumulative
    case eTime        = "t"
}


class ZTrait: ZRecord {

    
    @objc dynamic var  type: String?
    @objc dynamic var  text: String?
    @objc dynamic var  data: Data?
    @objc dynamic var asset: CKAsset?
    @objc dynamic var owner: CKRecord.Reference?
    var _traitType: ZTraitType? = nil
    var _ownerZone: Zone? = nil
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
            _ownerZone  = cloudManager?.maybeZoneForRecordID(owner?.recordID)
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


    class func cloudProperties() -> [String] {
        return[#keyPath(type),
               #keyPath(data),
               #keyPath(text),
               #keyPath(owner),
               #keyPath(asset)]
    }


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + ZTrait.cloudProperties()
    }


    override func orphan() {
        ownerZone?.setTraitText(nil, for: traitType)

        owner = nil

        updateRecordProperties()
    }


    override func unorphan() {
        if  let traits = ownerZone?.traits, let t = traitType, traits[t] == nil {
            ownerZone?.maybeMarkNotFetched()

            ownerZone?.traits[t] = self
        } else {
            needUnorphan()
        }
    }

}
