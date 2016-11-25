//
//  ZBookmarksManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/24/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZBookmarksManager: NSObject {


    var             ckzones:                          [Zone] = []
    var           bookmarks:                          [Zone] = []
    var recordZonesByZoneID: [CKRecordZoneID : CKRecordZone] = [:]


    func setupWithDict(_ dict: [CKRecordZoneID : CKRecordZone]) {
        recordZonesByZoneID = dict

        addCKZone("mine",     storageMode: .mine)
        addCKZone("everyone", storageMode: .everyone)
    }


    func addCKZone(_ name: String, storageMode: ZStorageMode) {
        let      zone = Zone(record: nil, storageMode: storageMode)
        zone.zoneName = name

        ckzones.append(zone)
    }
}
