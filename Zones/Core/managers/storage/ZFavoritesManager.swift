//
//  ZFavoritesManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/24/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


class ZFavoritesManager: ZRecordsManager {


    let  defaultFavorites  = Zone(record: nil, storageMode: .favorites)
    var    favoritesIndex  = 0
    var             count: Int { return rootZone!.count }


    // MARK:- init
    // MARK:-


    func setup() {
        if  rootZone          == nil {
            rootZone           = Zone(record: nil, storageMode: .favorites)
            rootZone?.level    = 0
            rootZone?.zoneName = "favorites"
            rootZone?.record   = CKRecord(recordType: zoneTypeKey, recordID: CKRecordID(recordName: favoritesRootNameKey))

            rootZone?.displayChildren()
            setupDefaultFavorites()
        }

        update()
    }


    func setupDefaultFavorites() {
        let createDefaultFavoriteAt = { (_ index: Int) in
            let  mode: ZStorageMode = index == 0 ? .everyone : .mine
            let                name = mode.rawValue
            let            favorite = self.create(withBookmark: nil, false, parent: self.defaultFavorites, atIndex: index, mode, name)
            favorite      .zoneLink =  "\(name)::"
            favorite         .order = Double(index) * 0.0001

            favorite.clearAllStates()
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
            rootZone?.removeChild(defaultFavorites[index])
        }

        var found = [Int] ()

        for favorite in rootZone!.children {
            if favorite.isFavorite, let mode = favorite.crossLink?.storageMode {

                switch mode {
                case .everyone: found.append(0); break
                case .mine:     found.append(1); break
                default:                         break
                }
            }
        }

        for index in [0, 1] {
            if !found.contains(index), let favorite = defaultFavorites[index] {

                rootZone?.addChild(favorite)
                favorite.clearAllStates()
            }
        }
    }


    func zoneAtIndex(_ index: Int) -> Zone? {
        return rootZone?[index]
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


    func updateIndexFor(_ iZone: Zone, iGrabClosure: ObjectClosure?) {
        setup()

        let        traveler = !iZone.isBookmark ? iZone : iZone.bookmarkTarget

        if  let identifier  = traveler?.record?.recordID.recordName {
            if  identifier == favoritesRootNameKey {
                iGrabClosure?(iZone)
            } else {
                let          mode = traveler!.storageMode
                let   enumeration = rotatedEnumeration
                let updateForZone = { (iZoneToMatch: Zone) in
                    for (index, zone) in self.rootZone!.children.enumerated() {
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

                iGrabClosure?(nil)
            }
        } else {
            iGrabClosure?(nil)
        }
    }


    // MARK:- switch
    // MARK:-


    func nextFavoritesIndex(forward: Bool) -> Int {
        update()

        let increment = (forward ? 1 : -1)
        var     index = favoritesIndex + increment
        let     count = rootZone!.count

        if index >= count {
            index = 0
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
        if rootZone!.count > favoritesIndex, let bookmark = rootZone?[favoritesIndex] {
            if bookmark.isFavorite {
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

        parent.addChild(bookmark, at: insertAt)
        bookmark.incrementProgenyCount(by: 0)
        bookmark.updateCloudProperties() // is this needed?

        return bookmark
    }


    @discardableResult func createBookmark(for zone: Zone, isFavorite: Bool) -> Zone {
        if isFavorite {
            let basis: ZRecord = !zone.isBookmark ? zone : zone.crossLink!
            let     recordName = basis.record.recordID.recordName

            for bookmark in rootZone!.children {
                if recordName == bookmark.crossLink?.record.recordID.recordName {
                    return bookmark
                }
            }
        }

        let    parent: Zone = isFavorite ? rootZone! : zone.parentZone ?? rootZone!
        let           count = parent.count
        var bookmark: Zone? = zone.isBookmark ? zone.deepCopy() : nil
        var           index = parent.children.index(of: zone) ?? count

        if isFavorite {
            updateIndexFor(zone) { object in }

            index           = nextFavoritesIndex(forward: asTask)
        }

        bookmark            = create(withBookmark: bookmark, isFavorite, parent: parent, atIndex: index, zone.storageMode, zone.zoneName)

        bookmark?.needCreate()

        if !isFavorite {
            parent.maybeNeedMerge()
            parent.updateCloudProperties()
        }

        if !zone.isBookmark {
            bookmark?.crossLink = zone
        }

        return bookmark!
    }


    func isChildOfFavoritesRoot(_ zone: Zone) -> Bool {
        let name = zone.record.recordID.recordName

        if  let children = rootZone?.children {
            for child in children {
                if child.crossLink?.record.recordID.recordName == name {
                    return true
                }
            }
        }

        return false
    }


    func toggleFavorite(for zone: Zone) {
        if isChildOfFavoritesRoot(zone) {
            gFavoritesManager.deleteFavorite(for: zone)
        } else {
            gFavoritesManager.createBookmark(for: zone, isFavorite: true)
        }
    }


    func deleteFavorite(for zone: Zone) {
        let recordID = zone.record.recordID

        for (index, favorite) in rootZone!.children.enumerated() {
            if  favorite.crossLink?.record.recordID == recordID {
                rootZone?.children.remove(at: index)

                break
            }
        }
    }
}
