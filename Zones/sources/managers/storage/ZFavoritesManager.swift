//
//  ZFavoritesManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/24/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


class ZFavoritesManager: ZCloudManager {


    // MARK:- initialization
    // MARK:-


    var       favoritesIndex = 0
    let     defaultFavorites = Zone(record: nil, storageMode: .favorites)
    let defaultModes: ZModes = [.everyone, .mine]
    let    favoritesFavorite = Zone(favoriteNamed: "favorites")
    var           count: Int { return rootZone?.count ?? 0 }


    var currentFavorite: Zone? {
        return zoneAtIndex(favoritesIndex)
    }


    var rotatedEnumeration: EnumeratedSequence<Array<Zone>> {
        let enumeration = rootZone?.children.enumerated()
        var     rotated = [Zone] ()

        for (index, favorite) in enumeration! {
            if  index >= favoritesIndex {
                rotated.append(favorite)
            }
        }

        for (index, favorite) in enumeration! {
            if  index < favoritesIndex {
                rotated.append(favorite)
            }
        }

        return rotated.enumerated()
    }


    func setup() {
        if  rootZone          == nil {
            rootZone           = Zone(record: nil, storageMode: .favorites)
            rootZone?.zoneName = "favorites"
            rootZone?.record   = CKRecord(recordType: zoneTypeKey, recordID: CKRecordID(recordName: favoritesRootNameKey))

            rootZone?.displayChildren()
            setupDefaultFavorites()
        }
    }


    func setupDefaultFavorites() {
        if defaultFavorites.count == 0 {
            for (index, mode) in defaultModes.enumerated() {
                let          name = mode.rawValue
                let      favorite = create(withBookmark: nil, false, parent: defaultFavorites, atIndex: index, mode, name)
                favorite.zoneLink =  "\(name)::"
                favorite   .order = Double(index) * 0.001

                favorite.clearAllStates()
            }
        }
    }


    // MARK:- API
    // MARK:-


    func update() {

        columnarReport(" FAVORITE", "UPDATE")

        let zone = currentFavorite

        // assure at least one favorite per db
        // call every time favorites MIGHT be altered
        // end of handleKey in editor

        for favorite in defaultFavorites.children {
            rootZone?.removeChild(favorite)
        }

        var found = ZModes ()

        for favorite in rootZone!.children {
            if favorite.isFavorite, let mode = favorite.crossLink?.storageMode, !found.contains(mode) {
                found.append(mode)
            }
        }

        for favorite in defaultFavorites.children {
            if let mode = favorite.storageMode, !found.contains(mode) {
                rootZone?.add(favorite)
                favorite.clearAllStates() // erase side-effect of add
            }
        }

        updateForZone(zone, nil)
    }


    func zoneAtIndex(_ index: Int) -> Zone? {
        if index < 0 || rootZone == nil || index >= rootZone!.count {
            return nil
        }

        return rootZone?[index]
    }
    

    func textAtIndex(_ index: Int) -> String? {
        return zoneAtIndex(index)?.zoneName
    }


    func showFavoritesAndGrab(_ zone: Zone?, _ atArrival: @escaping SignalClosure) {
        updateGrabAndIndexFor(zone)
        atArrival(zone, .redraw)
    }


    func updateGrabAndIndexFor(_ iGrab: Zone?) {
        if  let grab = iGrab {
            updateIndexFor(grab) { object in
                if  let zone = object as? Zone {
                    zone.grab()
                }
            }
        }
    }


    func updateForZone(_ iZone: Zone?, _ iGrabClosure: ObjectClosure?) {
        if  let target = iZone, target.storageMode == gStorageMode {
            for (index, zone) in self.rootZone!.children.enumerated() {
                if  zone == target {
                    self.favoritesIndex = index

                    iGrabClosure?(target)

                    return
                }
            }
        }
    }


    func updateIndexFor(_ iZone: Zone, iGrabClosure: ObjectClosure?) {
        let          traveler = !iZone.isBookmark ? iZone : iZone.bookmarkTarget
        if  let    identifier = traveler?.record?.recordID.recordName {
            let          mode = traveler!.storageMode
            let   enumeration = rotatedEnumeration

            // must go through enumerations three times, so will match
            // first against identifer
            // second against target
            // third against non-favorite ???

            for (_, zone) in enumeration {
                if zone == iZone || (zone.isFavorite && zone.crossLink?.record.recordID.recordName == identifier && zone.crossLink?.storageMode == mode) {
                    return updateForZone(zone, iGrabClosure)
                }
            }

            for (_, zone) in enumeration {
                if zone.isFavorite, let target = zone.bookmarkTarget, (target.spawned(traveler!) || traveler!.spawned(target)) {
                    return updateForZone(zone, iGrabClosure)
                }
            }

            for (_, zone) in enumeration {
                if !zone.isFavorite, zone.isBookmark, zone.crossLink?.storageMode == mode {
                    return updateForZone(zone, iGrabClosure)
                }
            }
        }

        iGrabClosure?(nil)
    }


    // MARK:- switch
    // MARK:-


    func nextFavoritesIndex(forward: Bool) -> Int {
        update()

        let increment = (forward ? 1 : -1)
        var     index = favoritesIndex + increment
        let     count = rootZone!.count

        if index >= count {
            index =       0
        } else if index < 0 {
            index = count - 1
        }

        return index
    }


    func nextFavorite(forward: Bool) -> Zone? {
        let index = nextFavoritesIndex(forward: forward)

        return rootZone!.count <= index ? nil : rootZone![index]
    }


    func nextName(forward: Bool) -> String {
        let name = nextFavorite(forward: forward)?.zoneName?.substring(to: 10)

        return name ?? ""
    }


    func switchToNext(_ forward: Bool, atArrival: @escaping Closure) {
        favoritesIndex = nextFavoritesIndex(forward: forward)

        if !refocus(atArrival) {
            switchToNext(forward, atArrival: atArrival)
        }
    }


    @discardableResult func refocus(_ atArrival: @escaping Closure) -> Bool {
        if  let bookmark = currentFavorite {
            if  bookmark.isFavorite {
                gTravelManager.travelThrough(bookmark) { (iObject: Any?, iKind: ZSignalKind) in
                    atArrival()
                }

                return true
            } else if let mode = bookmark.crossLink?.storageMode {
                gStorageMode = mode

                gTravelManager.travel {
                    gHere.grab()
                    atArrival()
                }

                return true
            }

        }

        performance("oops!")

        return false
    }

    // MARK:- create
    // MARK:-


    @discardableResult func create(withBookmark: Zone?, _ isFavorite: Bool, _ storageMode: ZStorageMode?, _ name: String?) -> Zone {
        let bookmark:  Zone = withBookmark ?? Zone(record: CKRecord(recordType: zoneTypeKey), storageMode: storageMode)
        bookmark.isFavorite = isFavorite
        bookmark.zoneName   = name

        return bookmark
    }


    @discardableResult func create(withBookmark: Zone?, _ isFavorite: Bool, parent: Zone, atIndex: Int, _ storageMode: ZStorageMode?, _ name: String?) -> Zone {
        let           count = parent.count
        let bookmark:  Zone = create(withBookmark: withBookmark, isFavorite, storageMode, name)
        let  insertAt: Int? = atIndex == count ? nil : atIndex

        parent.add(bookmark, at: insertAt) // calls update progeny count
        bookmark.updateCloudProperties() // is this needed?

        return bookmark
    }


    @discardableResult func createBookmark(for iZone: Zone, isFavorite: Bool) -> Zone {
        if isFavorite {
            let basis: ZRecord = !iZone.isBookmark ? iZone : iZone.crossLink!
            let     recordName = basis.record.recordID.recordName

            for bookmark in rootZone!.children {
                if recordName == bookmark.crossLink?.record.recordID.recordName, !defaultFavorites.children.contains(bookmark) {
                    return bookmark
                }
            }
        }

        let    parent: Zone = isFavorite ? rootZone! : iZone.parentZone ?? rootZone!
        let           count = parent.count
        var bookmark: Zone? = iZone.isBookmark ? iZone.deepCopy() : nil
        var           index = parent.children.index(of: iZone) ?? count

        if isFavorite {
            updateIndexFor(iZone) { object in }

            index           = nextFavoritesIndex(forward: gInsertionsFollow)
        }

        bookmark            = create(withBookmark: bookmark, isFavorite, parent: parent, atIndex: index, iZone.storageMode, iZone.zoneName)

        bookmark?.needFlush()

        if  isFavorite {
            updateGrabAndIndexFor(iZone)
        } else {
            parent.maybeNeedMerge()
            parent.updateCloudProperties()
        }

        if !iZone.isBookmark {
            bookmark?.crossLink = iZone
        }

        return bookmark!
    }


    func isChildOfFavoritesRoot(_ zone: Zone) -> Bool {
        let   recordName = zone.record.recordID.recordName

        if  let children = rootZone?.children {
            for child in children {
                if  recordName == child.crossLink?.record.recordID.recordName, !defaultFavorites.children.contains(child) {
                    return true
                }
            }
        }

        return false
    }


    func toggleFavorite(for zone: Zone) {
        if isChildOfFavoritesRoot(zone) {
            deleteFavorite(for: zone)
        } else {
            createBookmark(for: zone, isFavorite: true)
        }

        updateGrabAndIndexFor(zone)
    }


    func deleteFavorite(for zone: Zone) {
        let recordID = zone.record.recordID

        for (index, favorite) in rootZone!.children.enumerated() {
            if  favorite.crossLink?.record.recordID == recordID {
                favorite.needDestroy()

                rootZone?.children.remove(at: index)

                break
            }
        }
    }
}
