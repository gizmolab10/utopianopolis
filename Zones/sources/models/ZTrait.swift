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
    case eDuration  = "d" // accumulative
    case eEssay     = "e"
    case eGraphic   = "g"
    case eHyperlink = "h"
    case eMoney     = "m" // accumulative
    case eTime      = "t"
}


class ZTrait: ZRecord {

    
    dynamic var  type: String?
    dynamic var  text: String?
    dynamic var  data: Data?
    dynamic var asset: CKAsset?
    dynamic var owner: CKReference?
    var _traitType: ZTraitType? = nil
    var _zoneOwner: Zone? = nil


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


    var zoneOwner: Zone? {
        if  _zoneOwner == nil, let mode = storageMode {
            _zoneOwner  = gRemoteStoresManager.cloudManagerFor(mode).zRecordForRecordID(owner?.recordID) as? Zone
        }

        return _zoneOwner
    }


    convenience init(storageMode: ZStorageMode?) {
        self.init(record: CKRecord(recordType: gTraitTypeKey), storageMode: storageMode)
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


    override func unorphan() {
        if  let traits = zoneOwner?.traits, traits[.eHyperlink] == nil {
            zoneOwner?.traits[.eHyperlink] = self
        }
    }

}
