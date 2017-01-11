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


    let   rootZone = Zone(record: nil, storageMode: .bookmarks)
    var cloudzones = [Zone] ()
    var  bookmarks = [Zone] ()


    func setup() {
        rootZone.showChildren = true
        rootZone.zoneName     = "patchboard"

        setupCloudZonesForAccessToStorage()
    }


    func clear() {
        var orphans: [Zone] = []

        for child in rootZone.children {
            if !child.isBookmark {
                orphans.append(child)
            }
        }

        for orphan in orphans {
            orphan.orphan()
        }
    }


    func setupCloudZonesForAccessToStorage() {
        addCloudZone("everyone", storageMode: .everyone)
        addCloudZone("mine",     storageMode: .mine)
    }


    func addCloudZone(_ name: String, storageMode: ZStorageMode) { // KLUDGE, perhaps use ordered set or dictionary
        let      zone = Zone(record: nil, storageMode: storageMode)
        zone.zoneName = name
        zone.zoneLink = ""

        addNewBookmarkFor(zone, inPatchboard: false)
    }

    
    @discardableResult func addNewBookmarkFor(_ zone: Zone, inPatchboard: Bool) -> Zone {
        let            mode = zone.isRoot ? .bookmarks : gStorageMode
        let        bookmark = zone.isBookmark ? zone.deepCopy() : Zone(record: CKRecord(recordType: zoneTypeKey), storageMode: mode)
        let    parent: Zone = inPatchboard ? rootZone : zone.parentZone ?? rootZone
        let           index = parent.children.index(of: zone) ?? 0
        bookmark.zoneName   = zone.zoneName
        bookmark.parentZone = parent

        parent.addChild(bookmark, at: index)

        if !zone.isBookmark {
            bookmark.crossLink = zone
        }

        if mode != .bookmarks && gStorageMode != .bookmarks {
            parent.recomputeOrderingUponInsertionAt(index)
            parent.needSave()
            bookmark.needCreate()
        } else if inPatchboard {
            // save in manifest
            let  manifest = travelManager.manifest
            let reference = CKReference(record: bookmark.record, action: .none)

            manifest.bookmarks.append(reference)
            manifest.needSave()
            bookmark.needCreate()
        }

        return bookmark
    }
}
