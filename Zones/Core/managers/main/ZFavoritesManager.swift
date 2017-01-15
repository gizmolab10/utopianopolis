//
//  ZFavoritesManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/24/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZFavoritesManager: NSObject {


    let favoritesRootZone = Zone(record: nil, storageMode: .favorites)
    var favoritesIndex    = 0


    // MARK:- init
    // MARK:-


    func setup() {
        favoritesRootZone.showChildren = true
        favoritesRootZone.zoneName     = "favorites"

        setupRootFavorites()
    }


    func clear() {
        var toBeOrphaned: [Zone] = []

        for child in favoritesRootZone.children {
            if !child.isBookmark {
                toBeOrphaned.append(child)
            }
        }

        for zone in toBeOrphaned {
            zone.orphan()
        }
    }


    func setupRootFavorites() {
        if favoritesRootZone.children.count == 0 {
            createRootFavorite("everyone", order: 0.9999999, storageMode: .everyone)
            createRootFavorite("mine",     order: 0.9999998, storageMode: .mine)
        }
    }


    // MARK:- create
    // MARK:-
    

    func createRootFavorite(_ name: String, order: Double, storageMode: ZStorageMode) { // KLUDGE, perhaps use ordered set or dictionary
        let      zone = Zone(record: nil, storageMode: storageMode)
        zone.order    = order
        zone.zoneName = name
        zone.zoneLink = ""

        invokeWithMode(storageMode) {
            createBookmarkFor(zone, isFavorite: false)
        }
    }


    @discardableResult func createBookmarkFor(_ zone: Zone, isFavorite: Bool) -> Zone {
        let    parent: Zone = isFavorite ? favoritesRootZone : zone.parentZone ?? favoritesRootZone
        let           count = parent.children.count
        let           index = parent.children.index(of: zone) ?? count
        let        bookmark = zone.isBookmark ? zone.deepCopy() : Zone(record: CKRecord(recordType: zoneTypeKey), storageMode: gStorageMode)
        bookmark.zoneName   = zone.zoneName
        bookmark.isFavorite = isFavorite
        bookmark.parentZone = parent

        if isFavorite || index == count {
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


    // MARK:- switch
    // MARK:-


    func modeFor(_ rootBookmark: Zone) -> ZStorageMode? {
        // assume bookmark is not a favorite
        let mode = rootBookmark.crossLink?.storageMode

        if  mode != nil {
            for favorite in favoritesRootZone.children {
                if favorite.isFavorite && favorite.crossLink?.storageMode == mode {
                    return nil
                }
            }
        }

        return mode
    }


    func switchToNext(_ atArrival: @escaping Closure) {
        let      count = favoritesRootZone.children.count
        favoritesIndex = (favoritesIndex == 0 || favoritesIndex >= count ? count : favoritesIndex) - 1
        let   bookmark = favoritesRootZone.children[favoritesIndex]

        if bookmark.isFavorite {
            travelManager.changeFocusThroughZone(bookmark) { (iObject: Any?, iKind: ZSignalKind) in
                if (travelManager.hereZone?.isDeleted)! {
                    return self.switchToNext(atArrival)
                }

                atArrival()
            }
        } else if let mode = modeFor(bookmark) {
            gStorageMode = mode

            travelManager.travel(atArrival)
        } else {
            return switchToNext(atArrival)
        }

        // report(bookmark.zoneName)
    }
}
