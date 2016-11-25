//
//  ZTravelManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZTravelManager: NSObject {


    var     storageRootZone:                           Zone!
    var            rootZone:                           Zone!
    var             ckzones:                          [Zone] = []
    var           bookmarks:                          [Zone] = []
    var recordZonesByZoneID: [CKRecordZoneID : CKRecordZone] = [:]
    var         storageMode:                    ZStorageMode = .everyone


    func setup() {
        clear()
    }


    func clear() {
        rootZone          = Zone(record: nil, storageMode: storageMode)
        storageRootZone   = Zone(record: nil, storageMode: storageMode)
    }


    func setupWithDict(_ dict: [CKRecordZoneID : CKRecordZone]) {
        recordZonesByZoneID = dict

        if storageMode == .bookmarks {
            addCKZone("mine",     storageMode: .mine)
            addCKZone("everyone", storageMode: .everyone)
        }
    }


    func addCKZone(_ name: String, storageMode: ZStorageMode) {
        let        zone = Zone(record: nil, storageMode: storageMode)
        zone.parentZone = storageRootZone
        zone.zoneName   = name

        ckzones.append(zone)
    }


    func rootZoneForMode(_ mode: ZStorageMode) -> Zone? { return nil }


    func setRootZoneForMode(_ mode: ZStorageMode, zone: Zone?) {}


    func travelAction(_ action: ZTravelAction) {
        switch action {
        case .mine:      storageMode = .mine;      break
        case .everyone:  storageMode = .everyone;  break
        case .bookmarks: storageMode = .bookmarks; break
        }

        refresh()
    }


    func refresh() {
        widgetsManager  .clear()
        selectionManager.clear()
        clear()
        operationsManager.setupAndRun([ZSynchronizationState.cloud.rawValue, ZSynchronizationState.restore.rawValue, ZSynchronizationState.root.rawValue])
    }
}
