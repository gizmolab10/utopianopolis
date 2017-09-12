//
//  ZFavoritesManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/24/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


enum ZFavoriteStyle: Int {
    case normal
    case favorite
    case addFavorite
}


class ZFavoritesManager: ZCloudManager {


    // MARK:- initialization
    // MARK:-


    let     defaultFavorites = Zone(record: nil, storageMode: .favorites)
    let defaultModes: ZModes = [.everyone, .mine]
    let    favoritesFavorite = Zone(favoriteNamed: "favorites")
    var           count: Int { return rootZone?.count ?? 0 }


    var favoritesIndex: Int {
        return indexOf(favorite(for: gHere)) ?? userFavoritesIndex
    }


    var userFavoritesIndex: Int {
        get {
            if  let    value = UserDefaults.standard.object(forKey: favoritesIndexKey) as? Int {
                return value
            }

            let initialValue = 0

            UserDefaults.standard.set(initialValue, forKey: favoritesIndexKey)
            
            return initialValue
        }

        set {
            UserDefaults.standard.set(newValue, forKey: favoritesIndexKey)
        }
    }


    var currentFavorite: Zone? {
        return zoneAtIndex(favoritesIndex)
    }


    // create an enumeration where favorites graphically below current
    // are ordered before those that are graphically above and equal

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
                let      favorite = create(withBookmark: nil, .addFavorite, parent: defaultFavorites, atIndex: index, name)
                favorite.zoneLink =  "\(name)::"
                favorite   .order = Double(index) * 0.001

                favorite.clearAllStates()
            }
        }
    }


    // MARK:- API
    // MARK:-


    func updateChildren() {

        columnarReport(" FAVORITE", "UPDATE CHILDREN")

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
            if  let mode = favorite.crossLink?.storageMode, !found.contains(mode) {
                rootZone?.add(favorite)
                favorite.clearAllStates() // erase side-effect of add
            }
        }
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


    func favorite(for iTarget: Zone?) -> Zone? {
        var  found: Zone? = nil

        if  let favorites = rootZone?.children, let target = iTarget {
            var     level = 0

            for favorite in favorites {
                if let favoriteTarget = favorite.bookmarkTarget, let newLevel = favorite.bookmarkTarget?.level, newLevel > level, favoriteTarget.spawned(target) {
                    level = favoriteTarget.level
                    found = favorite
                }
            }
        }

        return found
    }


    func indexOf(_ iFavorite: Zone?) -> Int? {
        if  let favorite = iFavorite, let link = favorite.crossLink, link.storageMode == gStorageMode, let enumeration = rootZone?.children.enumerated() {
            for (index, zone) in enumeration {
                if  zone == favorite {
                    return index
                }
            }
        }

        return nil
    }


    // MARK:- switch
    // MARK:-


    func nextFavoritesIndex(forward: Bool) -> Int {
        updateChildren()

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
        let index = nextFavoritesIndex(forward: forward)
        let  next = zoneAtIndex(index)

        if !focus(on: next, atArrival) {
            switchToNext(forward, atArrival: atArrival)
        }
    }


    @discardableResult func refocus(_ atArrival: @escaping Closure) -> Bool {
        if  let favorite = currentFavorite {
            return focus(on: favorite, atArrival)
        }

        return false
    }


    @discardableResult func focus(on iFavorite: Zone?, _ atArrival: @escaping Closure) -> Bool {
        if  let bookmark = iFavorite {
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


    @discardableResult func create(withBookmark: Zone?, _ style: ZFavoriteStyle, _ name: String?) -> Zone {
        let bookmark:  Zone = withBookmark ?? Zone(record: CKRecord(recordType: zoneTypeKey), storageMode: .mine)
        bookmark.isFavorite = style != .normal
        bookmark.zoneName   = name

        return bookmark
    }


    @discardableResult func create(withBookmark: Zone?, _ style: ZFavoriteStyle, parent: Zone, atIndex: Int, _ name: String?) -> Zone {
        let           count = parent.count
        let bookmark:  Zone = create(withBookmark: withBookmark, style, name)
        let  insertAt: Int? = atIndex == count ? nil : atIndex

        if style != .favorite {
            parent.add(bookmark, at: insertAt) // calls update progeny count
        }
        
        bookmark.updateCloudProperties() // is this needed?

        return bookmark
    }


    @discardableResult func createBookmark(for iZone: Zone, style: ZFavoriteStyle) -> Zone {
        var    parent: Zone = iZone.parentZone ?? rootZone!

        if style != .normal {
            let basis: ZRecord = !iZone.isBookmark ? iZone : iZone.crossLink!
            let     recordName = basis.record.recordID.recordName
            parent             = rootZone!

            for bookmark in rootZone!.children {
                if recordName == bookmark.crossLink?.record.recordID.recordName, !defaultFavorites.children.contains(bookmark) {
                    return bookmark
                }
            }
        }

        let           count = parent.count
        var bookmark: Zone? = iZone.isBookmark ? iZone.deepCopy() : nil
        var           index = parent.children.index(of: iZone) ?? count

        if style == .addFavorite {
            index           = nextFavoritesIndex(forward: gInsertionsFollow)
        }

        bookmark            = create(withBookmark: bookmark, style, parent: parent, atIndex: index, iZone.zoneName)

        bookmark?.needFlush()

        if  style == .normal {
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
            createBookmark(for: zone, style: .addFavorite)
            updateChildren()
        }
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
