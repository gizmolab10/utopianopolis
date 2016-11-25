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


    var    rootZone:  Zone!
    var storageZone:  Zone!
    var  cloudzones: [Zone] = []
    var   bookmarks: [Zone] = []
    let         key: String = "current storage mode"


    var storageMode: ZStorageMode {
        set { UserDefaults.standard.set(newValue.rawValue, forKey:key) }
        get {
            var mode: ZStorageMode? = nil

            if let           object = UserDefaults.standard.object(forKey:key) {
                mode                = ZStorageMode(rawValue: object as! String)
            }

            if mode == nil {
                mode                = .everyone
                self.storageMode    = mode!
            }

            return mode!
        }
    }


    func setupBookmarks() {
        if storageMode == .bookmarks {
            rootZone.zoneName = "bookmarks"

            addCloudZone("mine",     storageMode: .mine)
            addCloudZone("everyone", storageMode: .everyone)
        }
    }


    func setup() {
        rootZone    = Zone(record: nil, storageMode: storageMode)
        storageZone = Zone(record: nil, storageMode: storageMode)

        setupBookmarks()
    }


    func addCloudZone(_ name: String, storageMode: ZStorageMode) {
        let        zone = Zone(record: nil, storageMode: storageMode)
        zone.parentZone = rootZone
        zone.zoneName   = name

        rootZone.children.append(zone)
    }


    func travelAction(_ action: ZTravelAction) {
        switch action {
        case .mine:      storageMode = .mine;      break
        case .everyone:  storageMode = .everyone;  break
        case .bookmarks: storageMode = .bookmarks; break
        }

        widgetsManager    .clear()
        selectionManager  .clear()
        setup                   ()
        operationsManager.travel()
    }
}
