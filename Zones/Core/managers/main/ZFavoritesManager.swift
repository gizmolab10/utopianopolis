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
    var       count: Int { get { return favoritesRootZone.count } }


    // MARK:- init
    // MARK:-


    func setup() {
        favoritesRootZone.level        = 0
        favoritesRootZone.showChildren = true
        favoritesRootZone.zoneName     = "favorites"
        favoritesRootZone.record       = CKRecord(recordType: zoneTypeKey, recordID: CKRecordID(recordName: favoritesRootNameKey))

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
            bookmark.order    = Double(index) * 0.0001
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
            if favorite.isFavorite, let mode = favorite.crossLink?.storageMode {

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


    func zoneAtIndex(_ index: Int) -> Zone? {
        return favoritesRootZone[index]
    }
    

    func textAtIndex(_ index: Int) -> String? {
        return zoneAtIndex(index)?.zoneName
    }


    func showFavoritesAndGrab(_ zone: Zone?, _ atArrival: @escaping SignalClosure) {
        gStorageMode = .favorites

        gTravelManager.travel {
            self.updateGrabAndIndexFor(zone)
            atArrival(zone, .redraw)
        }
    }


    func updateGrabAndIndexFor(_ iZone: Zone?) {
        if iZone != nil {
            updateIndexFor(iZone!) { object in
                if let zone = object as? Zone {
                    zone.grab()
                }
            }
        }
    }


    var rotatedEnumeration: EnumeratedSequence<Array<Zone>> {
        let enumeration = favoritesRootZone.children.enumerated()
        var     rotated = [Zone] ()

        for (index, favorite) in enumeration {
            if  index >= favoritesIndex {
                rotated.append(favorite)
            }
        }

        for (index, favorite) in enumeration {
            if  index < favoritesIndex {
                rotated.append(favorite)
            }
        }

        return rotated.enumerated()
    }


    func updateIndexFor(_ iZone: Zone, iGrabClosure: ObjectClosure?) {
        update()

        let        traveler = !iZone.isBookmark ? iZone : iZone.bookmarkTarget

        if  let identifier  = traveler?.record?.recordID.recordName {
            if  identifier == favoritesRootNameKey {
                iGrabClosure?(iZone)
            } else {
                let          mode = traveler!.storageMode
                let   enumeration = rotatedEnumeration
                let updateForZone = { (iZoneToMatch: Zone) in
                    for (index, zone) in self.favoritesRootZone.children.enumerated() {
                        if zone == iZoneToMatch {
                            self.favoritesIndex = index

                            iGrabClosure?(zone)

                            return
                        }
                    }
                }

                for (_, zone) in enumeration {
                    if zone == iZone || (zone.isFavorite && zone.crossLink?.record.recordID.recordName == identifier) {
                        return updateForZone(zone)
                    }
                }

                for (_, zone) in enumeration {
                    if zone.isFavorite, let target = zone.bookmarkTarget, (target.spawned(traveler!) || traveler!.spawned(target)) {
                        return updateForZone(zone)
                    }
                }

                for (_, zone) in enumeration {
                    if !zone.isFavorite, zone.isBookmark, zone.crossLink?.storageMode == mode {
                        return updateForZone(zone)
                    }
                }
            }
        }
    }


    // MARK:- switch
    // MARK:-


    func nextFavoritesIndex(forward: Bool) -> Int {
        update()

        let increment = (forward ? 1 : -1)
        var     index = favoritesIndex + increment
        let     count = favoritesRootZone.count

        if index >= count {
            index = 0
        } else if index < 0 {
            index = count - 1
        }

        return index
    }


    func nextFavorite(forward: Bool) -> Zone? {
        let index = nextFavoritesIndex(forward: forward)

        return favoritesRootZone.count <= index ? nil :favoritesRootZone[index]
    }


    func nextName(forward: Bool) -> String {
        let name = nextFavorite(forward: forward)?.zoneName?.substring(to: 10)

        return name ?? ""
    }


    func switchToNext(_ forward: Bool, atArrival: @escaping Closure) {
        favoritesIndex = nextFavoritesIndex(forward: forward)

        if favoritesRootZone.count > favoritesIndex {
            let bookmark = favoritesRootZone[favoritesIndex]!

            if bookmark.isFavorite {
                gTravelManager.travelThrough(bookmark) { (iObject: Any?, iKind: ZSignalKind) in
                    atArrival()
                }
            } else if let mode = bookmark.crossLink?.storageMode {
                gStorageMode = mode

                gTravelManager.travel {
                    gHere.grab()
                    atArrival()
                }
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
        let  insertAt: Int? = atIndex == count ? nil : atIndex

        parent.addChild(bookmark, at: insertAt)
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
        var bookmark: Zone? = zone.isBookmark ? zone.deepCopy() : nil
        var           index = parent.children.index(of: zone) ?? count

        if isFavorite {
            updateIndexFor(zone) { object in }

            index           = nextFavoritesIndex(forward: asTask)
        }

        bookmark            = create(withBookmark: bookmark, isFavorite, parent: parent, atIndex: index, zone.storageMode, zone.zoneName)

        if !isFavorite {
            parent.needUpdateSave()
        }

        if !zone.isBookmark {
            bookmark?.crossLink = zone
        }

        return bookmark!
    }
}
