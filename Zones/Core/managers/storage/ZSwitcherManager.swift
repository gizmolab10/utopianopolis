//
//  ZSwitcherManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/24/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZSwitcherManager: NSObject {


    let switcherRootZone = Zone(record: nil, storageMode: .switcher)


    func setup() {
        switcherRootZone.showChildren = true
        switcherRootZone.zoneName     = "switcher"

        setupCloudZonesForAccessToStorage()
    }


    func clear() {
        var orphans: [Zone] = []

        for child in switcherRootZone.children {
            if !child.isBookmark {
                orphans.append(child)
            }
        }

        for orphan in orphans {
            orphan.orphan()
        }
    }


    func setupCloudZonesForAccessToStorage() {
        if switcherRootZone.children.count == 0 {
            addCloudZone("everyone", storageMode: .everyone)
            addCloudZone("mine",     storageMode: .mine)
        }
    }


    func addCloudZone(_ name: String, storageMode: ZStorageMode) { // KLUDGE, perhaps use ordered set or dictionary
        let      zone = Zone(record: nil, storageMode: storageMode)
        zone.zoneName = name
        zone.zoneLink = ""

        addNewBookmarkFor(zone, inSwitcher: false)
    }

    
    @discardableResult func addNewBookmarkFor(_ zone: Zone, inSwitcher: Bool) -> Zone {
        let        bookmark = zone.isBookmark ? zone.deepCopy() : Zone(record: CKRecord(recordType: zoneTypeKey), storageMode: gStorageMode)
        let    parent: Zone = inSwitcher ? switcherRootZone : zone.parentZone ?? switcherRootZone
        let           index = parent.children.index(of: zone) ?? 0
        bookmark.zoneName   = zone.zoneName
        bookmark.isSwitcher = inSwitcher
        bookmark.parentZone = parent

        parent.needSave()
        parent.addChild(bookmark, at: index)
        parent.recomputeOrderingUponInsertionAt(index)

        if !zone.isBookmark {
            bookmark.crossLink = zone
        }

        bookmark.updateCloudProperties()
        bookmark.needCreate()

        return bookmark
    }    
}
