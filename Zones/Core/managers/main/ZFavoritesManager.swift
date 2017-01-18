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
        favoritesRootZone.storageMode  = .favorites
        favoritesRootZone.zoneName     = "favorites"
        favoritesRootZone.record       = CKRecord(recordType: zoneTypeKey, recordID: CKRecordID(recordName: "favoritesRoot"))

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


    // MARK:- private
    // MARK:-


    private func modeFor(_ rootBookmark: Zone) -> ZStorageMode? {
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


    private func nextFavorite(_ forward: Bool) -> Zone {
        let count = favoritesRootZone.count

        if forward {
            favoritesIndex = (favoritesIndex == 0 || favoritesIndex >= count ? count : favoritesIndex) - 1
        } else {
            favoritesIndex = favoritesIndex >= (count - 1) ? 0 : (favoritesIndex + 1)
        }

        return favoritesRootZone[favoritesIndex]!
    }


    // MARK:- switch
    // MARK:-


    private func updateForIndex(_ index: Int) {
        favoritesIndex = index

        selectionManager.grab(favoritesRootZone[index])
    }


    func updateGrabAndIndexFor(_ zone: Zone?) {
        if zone != nil {
            let identifier = zone?.record.recordID.recordName
            let       mode = zone?.storageMode

            for (index, favorite) in favoritesRootZone.children.enumerated() {
                if favorite.isFavorite && favorite.crossLink?.record.recordID.recordName == identifier {
                    return updateForIndex(index)
                }
            }

            for (index, favorite) in favoritesRootZone.children.enumerated() {
                if !favorite.isFavorite && favorite.crossLink?.storageMode == mode {
                    return updateForIndex(index)
                }
            }
        }
    }


    func switchToNext(_ forward: Bool, atArrival: @escaping Closure) {
        let bookmark = nextFavorite(forward)

        if bookmark.isFavorite {
            travelManager.changeFocusThroughZone(bookmark) { (iObject: Any?, iKind: ZSignalKind) in
                if (travelManager.hereZone?.isDeleted)! {
                    return self.switchToNext(forward) { atArrival() }
                }

                atArrival()
            }
        } else if let mode = modeFor(bookmark) {
            gStorageMode = mode

            travelManager.travel(atArrival)
        } else {
            return switchToNext(forward) { atArrival() }
        }

        // report(bookmark.zoneName)
    }


    // MARK:- create
    // MARK:-


    func setupRootFavorites() {
        if favoritesRootZone.count == 0 {
            createBookmark(atIndex: 0, .everyone)
            createBookmark(atIndex: 1, .mine)
        }
    }
    

    func createBookmark(atIndex: Int, _ mode: ZStorageMode) {
        let           name = mode.rawValue
        let       bookmark = create(withBookmark: nil, false, parent: favoritesRootZone, atIndex: atIndex, mode, name)
        bookmark?.zoneLink =  "\(name)::"
    }


    @discardableResult func create(withBookmark: Zone?, _ isFavorite: Bool, parent: Zone, atIndex: Int, _ storageMode: ZStorageMode?, _ name: String?) -> Zone? {
        let           count = parent.count
        let bookmark:  Zone = withBookmark ?? Zone(record: CKRecord(recordType: zoneTypeKey), storageMode: storageMode)
        bookmark.isFavorite = isFavorite
        bookmark.parentZone = parent
        bookmark.zoneName   = name

        if isFavorite || atIndex == count {
            parent.children.append(bookmark)
        } else {
            parent.addChild(bookmark, at: atIndex)
        }

        parent.recomputeOrderingUponInsertionAt(atIndex)
        bookmark.updateCloudProperties() // is this needed?
        bookmark.needCreate()

        return bookmark
    }


    @discardableResult func createBookmarkFor(_ zone: Zone, isFavorite: Bool) -> Zone {
        let    parent: Zone = isFavorite ? favoritesRootZone : zone.parentZone ?? favoritesRootZone
        let           count = parent.count
        let           index = parent.children.index(of: zone) ?? count
        var bookmark: Zone? = zone.isBookmark ? zone.deepCopy() : nil
        bookmark            = create(withBookmark: bookmark, isFavorite, parent: parent, atIndex: index, zone.storageMode, zone.zoneName)

        if !isFavorite {
            parent.needSave()
        }

        if !zone.isBookmark {
            bookmark?.crossLink = zone
        }

        return bookmark!
    }
}
