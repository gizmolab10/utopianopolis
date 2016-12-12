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


    let   rootZone:  Zone! = Zone(record: nil, storageMode: .bookmarks)
    var cloudzones: [Zone] = []
    var  bookmarks: [Zone] = []


    func setup() {
        rootZone.showChildren = true
        rootZone.zoneName     = "bookmarks"

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

        addNewBookmarkFor(zone)
    }

    
    @discardableResult func addNewBookmarkFor(_ zone: Zone) -> Zone {
        let            mode = zone.isRoot ? .bookmarks : travelManager.storageMode
        let        bookmark = zone.isBookmark ? zone.deepCopy() : Zone(record: nil, storageMode: mode)
        let    parent: Zone = zone.parentZone ?? rootZone
        bookmark.zoneName   = zone.zoneName
        bookmark.parentZone = parent

        if !zone.isBookmark {
            bookmark.crossLink = zone
        }

        parent.addChild(bookmark)

        if !zone.isRoot {
            parent.recomputeOrderingUponInsertionAt(parent.children.count - 1)
        }

        return bookmark
    }
}
