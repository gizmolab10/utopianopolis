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
    let defaultFavorites  = Zone(record: nil, storageMode: .favorites)
    var favoritesIndex    = 0


    // MARK:- init
    // MARK:-


    func setup() {
        favoritesRootZone.showChildren = true
        favoritesRootZone.zoneName     = "favorites"
        favoritesRootZone.record       = CKRecord(recordType: zoneTypeKey, recordID: CKRecordID(recordName: "favoritesRoot"))

        setupDefaultFavorites()
        update()
    }


    func setupDefaultFavorites() {
        let modeAtIndex = { (_ index: Int) -> ZStorageMode in
            switch index {
            case 0:  return .everyone
            default: return .mine
            }
        }

        let createDefaultFavoriteAt = { (_ index: Int) in
            let          mode = modeAtIndex(index)
            let          name = mode.rawValue
            let      bookmark = self.create(withBookmark: nil, false, parent: self.defaultFavorites, atIndex: index, mode, name)
            bookmark.zoneLink =  "\(name)::"
        }

        if defaultFavorites.count == 0 {
            for index in [0, 1] {
                createDefaultFavoriteAt(index)
            }
        }
    }


    // MARK:- API
    // MARK:-


    func update() {
        // assure at least one favorite per db
        // call every time favorites MIGHT be altered
        // end of handleKey in editor

        for index in [0, 1] {
            favoritesRootZone.removeChild(defaultFavorites[index])
        }

        var found = [Int] ()

        for favorite in favoritesRootZone.children {
            if favorite.isFavorite {
                let mode = (favorite.crossLink?.storageMode)!

                switch mode {
                case .everyone: found.append(0); break
                case .mine:     found.append(1); break
                default:                         break
                }
            }
        }

        for index in [0, 1] {
            if !found.contains(index) {
                favoritesRootZone.addChild(defaultFavorites[index])
            }
        }
    }


    func showFavoritesAndGrab(_ zone: Zone?, _ atArrival: @escaping SignalClosure) {
        gStorageMode = .favorites

        update()
        travelManager.travel {
            self.updateGrabAndIndexFor(zone)
            atArrival(zone, .redraw)
        }
    }


    // MARK:- internals
    // MARK:-


    func updateGrabAndIndexFor(_ zone: Zone?) {
        update()

        let updateForIndex = { (_ index: Int) in
            self.favoritesIndex = index

            selectionManager.grab(self.favoritesRootZone[index])
        }

        if zone != nil {
            let     identifier = zone?.record.recordID.recordName
            let           mode = zone?.storageMode

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

        updateForIndex(0)
    }


    private func incrementFavoritesIndex(by: Int) -> Int {
        update()

        var index = favoritesIndex + by
        let count = favoritesRootZone.count

        if index >= count {
            index = 0
        } else if by < 0 && index <= 0 {
            index = count - 1
        }

        return index
    }


    // MARK:- switch
    // MARK:-


    func nextFavorite(forward: Bool) -> Zone? {
        let  increment = (forward ? 1 : -1)
        let      index = incrementFavoritesIndex(by: increment)

        return favoritesRootZone.count <= index ? nil :favoritesRootZone[index]
    }


    func switchToNext(_ forward: Bool, atArrival: @escaping Closure) {
        let  increment = (forward ? 1 : -1)
        favoritesIndex = incrementFavoritesIndex(by: increment)

        if favoritesRootZone.count > favoritesIndex {
            let bookmark = favoritesRootZone[favoritesIndex]!

            if bookmark.isFavorite {
                travelManager.travelThrough(bookmark) { (iObject: Any?, iKind: ZSignalKind) in
                    if (travelManager.hereZone?.isDeleted)! {
                        return self.switchToNext(forward) { atArrival() }
                    }

                    atArrival()
                }
            } else if let mode = bookmark.crossLink?.storageMode {
                gStorageMode = mode

                travelManager.travel(atArrival)
            } else {
                return switchToNext(forward) { atArrival() }
            }
            
            // report(bookmark.zoneName)
        } else {
            report("oops!")
        }
    }


    // MARK:- create
    // MARK:-


    @discardableResult func create(withBookmark: Zone?, _ isFavorite: Bool, _ storageMode: ZStorageMode?, _ name: String?) -> Zone {
        let bookmark:  Zone = withBookmark ?? Zone(record: CKRecord(recordType: zoneTypeKey), storageMode: storageMode)
        bookmark.isFavorite = isFavorite
        bookmark.zoneName   = name

        bookmark.needCreate()

        return bookmark
    }


    @discardableResult func create(withBookmark: Zone?, _ isFavorite: Bool, parent: Zone, atIndex: Int, _ storageMode: ZStorageMode?, _ name: String?) -> Zone {
        let           count = parent.count
        let bookmark:  Zone = create(withBookmark: withBookmark, isFavorite, storageMode, name)
        let  insertAt: Int? = isFavorite || atIndex == count ? nil : atIndex

        parent.addAndReorderChild(bookmark, at: insertAt)
        bookmark.updateCloudProperties() // is this needed?

        return bookmark
    }


    @discardableResult func createBookmarkFor(_ zone: Zone, isFavorite: Bool) -> Zone {
        if isFavorite {
            let basis: ZRecord = !zone.isBookmark ? zone : zone.crossLink!
            let     recordName = basis.record.recordID.recordName

            for bookmark in favoritesRootZone.children {
                if bookmark.isFavorite, recordName == bookmark.crossLink?.record.recordID.recordName {
                    return bookmark
                }
            }
        }

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
