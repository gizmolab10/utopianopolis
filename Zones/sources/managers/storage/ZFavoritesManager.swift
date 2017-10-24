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


    let     defaultFavorites = Zone(record: nil, storageMode: .favoritesMode)
    let defaultModes: ZModes = [.everyoneMode, .mineMode]
    let    favoritesFavorite = Zone(favorite: gFavoritesKey)
    var           count: Int { return rootZone?.count ?? 0 }


    var actionTitle: String {
        if  gHere.isGrabbed,
            let     target = currentFavorite?.bookmarkTarget {
            let isFavorite = gHere == target

            return isFavorite ? "Unfavorite" : "Favorite"
        }

        return "Focus"
    }


    var favoritesIndex: Int {
        return indexOf(currentFavoriteID) ?? 0
    }


    var currentFavoriteID: String? {
        get {
            if  let    identifier = UserDefaults.standard.object(forKey: currentFavoriteKey) as? String {
                return identifier
            }

            if  let initialID = zoneAtIndex(0)?.record.recordID.recordName {

                //////////////////////////////////////////////////////////////////////////////////////
                // initial default value is first item in favorites list, whatever it happens to be //
                //////////////////////////////////////////////////////////////////////////////////////

                UserDefaults.standard.set(initialID, forKey: currentFavoriteKey)

                return initialID
            }

            return nil
        }

        set {
            UserDefaults.standard.set(newValue, forKey: currentFavoriteKey)
        }
    }


    var currentFavorite: Zone? {
        get {
            return zoneAtIndex(favoritesIndex)
        }

        set {
            if  let identifier = newValue?.record.recordID.recordName {
                currentFavoriteID = identifier
            }
        }
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


    private func zoneAtIndex(_ index: Int) -> Zone? {
        if index < 0 || rootZone == nil || index >= count {
            return nil
        }

        return rootZone?[index]
    }


    func indexOf(_ iFavoriteID: String?) -> Int? {
        if  let identifier = iFavoriteID, let enumeration = rootZone?.children.enumerated() {
            for (index, zone) in enumeration {
                if  zone.record.recordID.recordName == identifier {
                    return index
                }
            }
        }

        return nil
    }
    

    func favorite(for iTarget: Zone?, iSpawned: Bool = true) -> Zone? {
        var               found: Zone? = nil

        if  let              favorites = rootZone?.children,
            let                 target = iTarget,
            let                   mode = target.storageMode {
            var                  level = Int.max

            for favorite in favorites {
                if  let favoriteTarget = favorite.bookmarkTarget,
                    let     targetMode = favoriteTarget.storageMode,
                    let       newLevel = favorite.bookmarkTarget?.level,
                    newLevel           < level,
                    targetMode        == mode {
                    let        spawned = iSpawned ? target.spawned(favoriteTarget) : favoriteTarget.spawned(target)

                    if spawned {
                        level          = newLevel
                        found          = favorite
                    }
                }
            }
        }

        if iSpawned && found == nil {
            return favorite(for: iTarget, iSpawned: false)
        }

        return found
    }





    // MARK:- setup
    // MARK:-


    func setup() {
        if  rootZone                    == nil {
            let                   record = CKRecord(recordType: gZoneTypeKey, recordID: CKRecordID(recordName: gFavoriteRootNameKey))
            rootZone                     = Zone(record: record, storageMode: .mineMode)
            rootZone!          .zoneName = gFavoritesKey
            rootZone!.progenyAreWritable = true

            setupDefaultFavorites()
            rootZone!.needChildren()
            rootZone!.displayChildren()
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
        var hasTrash = false
        var    found = ZModes ()

        columnarReport(" FAVORITE", "UPDATE CHILDREN")

        // assure at least one favorite per db
        // call every time favorites MIGHT be altered
        // end of handleKey in editor

        for favorite in defaultFavorites.children {
            rootZone?.removeChild(favorite)
        }

        for favorite in rootZone!.children {
            if let mode = favorite.crossLink?.storageMode, !found.contains(mode) {
                found.append(mode)
            }

            if  let link = favorite.zoneLink, link == gTrashLink {
                hasTrash = true
            }
        }

        for favorite in defaultFavorites.children {
            if  let mode = favorite.crossLink?.storageMode,
                (!found.contains(mode) || favorite.isTrashRoot) {
                rootZone?.add(favorite)
                favorite.clearAllStates() // erase side-effect of add
            }
        }

        if !hasTrash && gTrash != nil {
            let      trash = createBookmark(for: gTrash!, style: .addFavorite)
            trash.zoneLink = gTrashLink
            trash   .order = 0.999

            trash.clearAllStates()
            trash.needFlush()
        }

        updateCurrentFavorite()
    }


    var hereSpawnedCurrentFavorite: Bool {
        if  let target = currentFavorite?.bookmarkTarget, currentFavorite != nil {
            return gHere.spawned(target)
        }

        return false
    }


    func updateCurrentFavorite() {
        if  let    favorite = favorite(for: gHere),
            let      target = favorite.bookmarkTarget,
            (!hereSpawnedCurrentFavorite || gHere == target) {
            currentFavorite = favorite
        }
    }


    // MARK:- switch
    // MARK:-


    func nextFavoritesIndex(forward: Bool) -> Int {
        return next(favoritesIndex, forward)
    }


    func next(_ index: Int, _ forward: Bool) -> Int {
        let increment = (forward ? 1 : -1)
        var      next = index + increment
        let     count = rootZone!.count

        if next >= count {
            next =       0
        } else if next < 0 {
            next = count - 1
        }

        return next
    }


    func switchToNext(_ forward: Bool, atArrival: @escaping Closure) {
        let    index = nextFavoritesIndex(forward: forward)
        var     bump : IntClosure?
        bump         = { (iIndex: Int) in
            let zone = self.zoneAtIndex(iIndex)

            if !self.focus(on: zone, atArrival) {
                bump?(self.next(index, forward))
            }
        }

        bump?(index)
    }


    @discardableResult func refocus(_ atArrival: @escaping Closure) -> Bool {
        if  let favorite = currentFavorite {
            return focus(on: favorite, atArrival)
        }

        return false
    }


    @discardableResult func focus(on iFavorite: Zone?, _ atArrival: @escaping Closure) -> Bool {
        if  let bookmark = iFavorite, bookmark.isBookmark {
            if  bookmark.isInFavorites {
                currentFavorite = bookmark

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
        let bookmark: Zone = withBookmark ?? Zone(record: CKRecord(recordType: gZoneTypeKey), storageMode: .mineMode)
        bookmark.zoneName  = name

        return bookmark
    }


    @discardableResult func create(withBookmark: Zone?, _ style: ZFavoriteStyle, parent: Zone, atIndex: Int, _ name: String?) -> Zone {
        let bookmark: Zone = create(withBookmark: withBookmark, style, name)
        let insertAt: Int? = atIndex == parent.count ? nil : atIndex

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
                    currentFavorite = bookmark

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


    // MARK:- toggle
    // MARK:-


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
