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

    
    dynamic var  type: String?
    dynamic var  text: String?
    dynamic var  data: Data?
    dynamic var asset: CKAsset?
    dynamic var owner: CKReference?
    var _traitType: ZTraitType? = nil
    var _ownerZone: Zone? = nil


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
