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


let         gFavoritesManager = ZFavoritesManager(.favoritesMode)
let gAllDatabaseModes: ZModes = [.everyoneMode, .mineMode]


class ZFavoritesManager: ZCloudManager {


    // MARK:- initialization
    // MARK:-


    let databaseRootFavorites = Zone(record: nil, storageMode: .favoritesMode)
    var      workingFavorites = [Zone] ()
    var                 count : Int  { return rootZone?.count ?? 0 }


    var hasTrash: Bool {
        for favorite in workingFavorites {
            if  let target = favorite.bookmarkTarget, target.isTrash {
                return true
            }
        }

        return false
    }


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
            if  let    identifier = UserDefaults.standard.object(forKey: kCurrentFavorite) as? String {
                return identifier
            }

            if  let initialID = zoneAtIndex(0)?.recordName {

                //////////////////////////////////////////////////////////////////////////////////////
                // initial default value is first item in favorites list, whatever it happens to be //
                //////////////////////////////////////////////////////////////////////////////////////

                UserDefaults.standard.set(initialID, forKey: kCurrentFavorite)

                return initialID
            }

            return nil
        }

        set {
            UserDefaults.standard.set(newValue, forKey: kCurrentFavorite)
        }
    }


    var currentFavorite: Zone? {
        get {
            return zoneAtIndex(favoritesIndex)
        }

        set {
            if  let identifier = newValue?.recordName {
                currentFavoriteID = identifier
            }
        }
    }


    // create an enumeration where favorites graphically below current
    // are ordered before those that are graphically above and equal

    var rotatedEnumeration: EnumeratedSequence<Array<Zone>> {
        let enumeration = workingFavorites.enumerated()
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


    var hereSpawnedTargetOfCurrentFavorite: Bool {
        if  let target = currentFavorite?.bookmarkTarget {
            return target.spawnedBy(gHere)
        }

        return false
    }


    private func zoneAtIndex(_ index: Int) -> Zone? {
        if index < 0 || index >= workingFavorites.count {
            return nil
        }

        return workingFavorites[index]
    }


    func indexOf(_ iFavoriteID: String?) -> Int? {
        if  let identifier = iFavoriteID {
            for (index, zone) in workingFavorites.enumerated() {
                if  zone.recordName == identifier {
                    return index
                }
            }
        }

        return nil
    }
    

    func favorite(for iTarget: Zone?, iSpawned: Bool = true) -> Zone? {
        var               found: Zone? = nil

        if  let                 target = iTarget,
            let                   mode = target.storageMode,
            let                   name = target.recordName {
            var                  level = Int.max

            for favorite in workingFavorites {
                if  let favoriteTarget = favorite.bookmarkTarget,
                    let     targetMode = favoriteTarget.storageMode,
                    targetMode        == mode {

                    if  name == favoriteTarget.recordName {
                        return favorite
                    }

                    let       newLevel = favoriteTarget.level

                    if        newLevel < level {
                        let    spawned = iSpawned ? target.spawnedBy(favoriteTarget) : favoriteTarget.spawnedBy(target)

                        if spawned {
                            level      = newLevel
                            found      = favorite
                        }
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
        if  gHasPrivateDatabase && rootZone == nil {
            rootZone               = Zone(storageMode: .mineMode, named: kFavoritesName, identifier: kFavoriteRootName)
            rootZone!.directAccess = .eChildrenWritable

            setupDatabaseFavorites()
            rootZone!.needProgeny()
            rootZone!.displayChildren()
        }
    }


    func setupDatabaseFavorites() {
        if databaseRootFavorites.count == 0 {
            for (index, mode) in gAllDatabaseModes.enumerated() {
                let          name = mode.rawValue
                let      favorite = create(withBookmark: nil, .addFavorite, parent: databaseRootFavorites, atIndex: index, name, identifier: kLocalNamePrefix + name)
                favorite.zoneLink =  "\(name)\(kSeparator)\(kSeparator)"
                favorite   .order = Double(index) * 0.001

                favorite.clearAllStates()
            }
        }
    }


    // MARK:- API
    // MARK:-


    func updateWorkingFavorites() {
        workingFavorites.removeAll()

        rootZone?.traverseAllProgeny { iChild in
            if iChild.isBookmark {
                self.workingFavorites.append(iChild)
            } else {
                iChild.displayChildren()
            }
        }
    }


    func updateFavorites() {
        if  gHasPrivateDatabase {
            var trashCopies = IndexPath()
            var  foundModes = ZModes ()
            var  foundTrash = false

            ////////////////////////////////////////////////
            // assure at least one root favorite per db   //
            // call every time favorites MIGHT be altered //
            ////////////////////////////////////////////////

            updateWorkingFavorites()

            /////////////////////////////////////////
            // detect modes which have bookmarks   //
            // remove all leftover trash bookmarks //
            /////////////////////////////////////////

            for (index, favorite) in workingFavorites.enumerated() {
                if  let link  = favorite.zoneLink {
                    if  link == kTrashLink {
                        if !foundTrash {
                            foundTrash = true
                        } else {
                            trashCopies.append(index)
                        }
                    } else if      favorite.isLocalOnly,
                        let    t = favorite.bookmarkTarget,
                        let mode = t.storageMode,
                        t.isRoot,
                        !foundModes.contains(mode) {
                        foundModes.append(mode)
                    }
                }
            }

            while   let index = trashCopies.popLast() {
                if  let trash = zoneAtIndex(index) {
                    trash.needDestroy()
                    trash.orphan()
                }
            }

            ////////////////////////////////
            // add missing trash favorite //
            ////////////////////////////////

            if !foundTrash {
                let      trash = Zone(storageMode: .mineMode, named: kTrashName, identifier: kLocalNamePrefix + kTrashName)
                trash.zoneLink = kTrashLink // convert into a bookmark

                rootZone?.addAndReorderChild(trash, at: nil)
                trash.clearAllStates()
            }

            ////////////////////////////////
            // add missing root favorites //
            ////////////////////////////////

            for favorite in databaseRootFavorites.children {
                if  let        mode = favorite.crossLink?.storageMode, !foundModes.contains(mode) {
                    let         add = favorite.deepCopy()
                    add.isLocalOnly = true

                    rootZone?.add(add)
                    add.clearAllStates() // erase side-effect of add
                }
            }

            updateWorkingFavorites()
            updateCurrentFavorite()
        }
    }


    func updateCurrentFavorite() {
        if  let     favorite = favorite(for: gHere),
            let       target = favorite.bookmarkTarget,
            (gHere == target || !hereSpawnedTargetOfCurrentFavorite) {
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
        let     count = workingFavorites.count

        if next >= count {
            next =       0
        } else if next < 0 {
            next = count - 1
        }

        return next
    }


    func switchToNext(_ forward: Bool, atArrival: @escaping Closure) {
        updateWorkingFavorites()

        let    index = nextFavoritesIndex(forward: forward)
        var     bump : IntClosure?
        bump         = { (iIndex: Int) in
            let zone = self.zoneAtIndex(iIndex)

            if !self.travel(into: zone, atArrival) {
                bump?(self.next(iIndex, forward))
            }
        }

        bump?(index)
    }


    @discardableResult func refocus(_ atArrival: @escaping Closure) -> Bool {
        if  let favorite = currentFavorite {
            return travel(into: favorite, atArrival)
        }

        return false
    }


    @discardableResult func travel(into iBookmark: Zone?, _ atArrival: @escaping Closure) -> Bool {
        if  let bookmark = iBookmark, bookmark.isBookmark {
            if  bookmark.isInFavorites {
                bookmark.bookmarkTarget?.parentZone?.displayChildren()
                gTravelManager.travelThrough(bookmark) { (iObject: Any?, iKind: ZSignalKind) in
                    self.updateFavorites()
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

            performance("oops!")
        }

        return false
    }


    // MARK:- create
    // MARK:-


    @discardableResult func create(withBookmark: Zone?, _ iName: String?, identifier: String? = nil) -> Zone {
        let           isLocal = identifier != nil
        if  let          name = iName,
            let      bookmark = withBookmark,
            isLocal          == bookmark.isLocalOnly {
            bookmark.zoneName = name

            return bookmark
        }

        return withBookmark ?? Zone(storageMode: .mineMode, named: iName, identifier: identifier)
    }


    @discardableResult func create(withBookmark: Zone?, _ style: ZFavoriteStyle, parent: Zone, atIndex: Int, _ name: String?, identifier: String? = nil) -> Zone {
        let bookmark: Zone = create(withBookmark: withBookmark, name, identifier: identifier)
        let insertAt: Int? = atIndex == parent.count ? nil : atIndex

        if style != .favorite {
            parent.add(bookmark, at: insertAt) // calls update progeny count
        }
        
        bookmark.updateRecordProperties() // is this needed?

        return bookmark
    }


    @discardableResult func createBookmark(for iZone: Zone, style: ZFavoriteStyle) -> Zone {
        var parent: Zone = iZone.parentZone ?? rootZone!
        let   isBookmark = iZone.isBookmark
        let     isNormal = style == .normal

        if  !isNormal {
            let basis: ZRecord = isBookmark ? iZone.crossLink! : iZone

            if  let recordName = basis.recordName {
                parent         = rootZone!

                for bookmark in workingFavorites {
                    if recordName == bookmark.linkName, !bookmark.bookmarkTarget!.isRoot {
                        currentFavorite = bookmark

                        return bookmark
                    }
                }
            }
        }

        let           count = parent.count
        var bookmark: Zone? = isBookmark ? iZone.deepCopy() : nil
        var           index = parent.children.index(of: iZone) ?? count

        if style == .addFavorite {
            index           = nextFavoritesIndex(forward: gInsertionsFollow)
        }

        bookmark            = create(withBookmark: bookmark, style, parent: parent, atIndex: index, iZone.zoneName)

        bookmark?.maybeNeedSave()

        if  isNormal {
            parent.updateRecordProperties()
            parent.maybeNeedMerge()
        }

        if !isBookmark {
            bookmark?.crossLink = iZone
        }

        return bookmark!
    }


    // MARK:- toggle
    // MARK:-


    func isWorkingFavorite(_ iZone: Zone) -> Bool {
        for     iChild in workingFavorites {
            if  iChild == iZone {
                return true
            }
        }

        return false
    }


    func toggleFavorite(for zone: Zone) {
        if  gHasPrivateDatabase {
            if  isWorkingFavorite  (zone) {
                deleteFavorite(for: zone)
            } else {
                createBookmark(for: zone, style: .addFavorite)
            }

            updateFavorites()
        }
    }


    func deleteFavorite(for zone: Zone) {
        let recordID = zone.record.recordID

        for favorite in workingFavorites {
            if  favorite.crossLink?.record.recordID == recordID {
                favorite.needDestroy()
                favorite.orphan()

                return
            }
        }
    }
}
