//
//  ZCloudZone.swift
//  Zones
//
//  Created by Jonathan Sand on 11/24/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZCloudZone: NSObject {


    var cloudZoneID: CKRecordZoneID? {
        get {
//            if zoneID == nil {
//                let database = cloudManager.databaseForMode(storageMode)
//                zoneID = cloudManager
//            }

            return nil // CKRecordZone.initWithZoneID(zoneID)
        }
    }


    init(_ name: String, storageMode: ZStorageMode, zoneID: CKRecordZoneID?) {
        super.init(record: nil, storageMode: storageMode)

        zoneName = String(name)
    }
}
