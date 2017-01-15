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
    var switcherIndex    = 0


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
            addCloudZone("everyone", order: 0.9999999, storageMode: .everyone)
            addCloudZone("mine",     order: 0.9999998, storageMode: .mine)
        }
    }


    func addCloudZone(_ name: String, order: Double, storageMode: ZStorageMode) { // KLUDGE, perhaps use ordered set or dictionary
        let      zone = Zone(record: nil, storageMode: storageMode)
        zone.order    = order
        zone.zoneName = name
        zone.zoneLink = ""

        invokeWithMode(storageMode) {
            addNewBookmarkFor(zone, isSwitcher: false)
        }
    }


    func modeFor(_ bookmark: Zone) -> ZStorageMode? {
        let mode = bookmark.crossLink?.storageMode

        if mode != nil {
            for switcher in switcherRootZone.children {
                if switcher.isSwitcher && switcher.crossLink?.storageMode == mode {
                    return nil
                }
            }
        }

        return mode
    }


    func switchToNext(_ atArrival: @escaping Closure) {
        switcherIndex = (switcherIndex == 0 ? switcherRootZone.children.count : switcherIndex) - 1
        let  bookmark = switcherRootZone.children[switcherIndex]

        if bookmark.isSwitcher {
            travelManager.changeFocusThroughZone(bookmark) { (iObject: Any?, iKind: ZSignalKind) in
                atArrival()
            }
        } else if let mode = modeFor(bookmark) {
            gStorageMode = mode

            travelManager.travel(atArrival)
        } else {
            switchToNext(atArrival)

            return
        }

        report(bookmark.zoneName)
    }


    @discardableResult func addNewBookmarkFor(_ zone: Zone, isSwitcher: Bool) -> Zone {
        let    parent: Zone = isSwitcher ? switcherRootZone : zone.parentZone ?? switcherRootZone
        let           count = parent.children.count
        let           index = parent.children.index(of: zone) ?? count
        let        bookmark = zone.isBookmark ? zone.deepCopy() : Zone(record: CKRecord(recordType: zoneTypeKey), storageMode: gStorageMode)
        bookmark.zoneName   = zone.zoneName
        bookmark.isSwitcher = isSwitcher
        bookmark.parentZone = parent

        if isSwitcher || index == count {
            parent.children.append(bookmark)
        } else {
            parent.addChild(bookmark, at: index)
        }

        if !zone.isBookmark {
            bookmark.crossLink = zone
        }

        parent.needSave()
        parent.recomputeOrderingUponInsertionAt(index)
        bookmark.updateCloudProperties()
        bookmark.needCreate()

        return bookmark
    }
}
