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


let gFavoritesManager = ZFavoritesManager(.favoritesMode)


class ZFavoritesManager: ZCloudManager {


    // MARK:- initialization
    // MARK:-


    let databaseModes: ZModes = [.everyoneMode, .mineMode]
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
                if  zone.record.recordID.recordName == identifier {
                    return index
                }
            }
        }

        return nil
    }
    

    func favorite(for iTarget: Zone?, iSpawned: Bool = true) -> Zone? {
        var               found: Zone? = nil

        if  let                 target = iTarget,
            let                   mode = target.storageMode {
            var                  level = Int.max

            for favorite in workingFavorites {
                if  let favoriteTarget = favorite.bookmarkTarget,
                    let     targetMode = favoriteTarget.storageMode,
                    targetMode        == mode {
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
            let             record = CKRecord(recordType: gZoneTypeKey, recordID: CKRecordID(recordName: gFavoriteRootNameKey))
            rootZone               = Zone(record: record, storageMode: .mineMode)
            rootZone!    .zoneName = gFavoritesKey
            rootZone!.directAccess = .eChildrenWritable

            setupDatabaseFavorites()
            rootZone!.needChildren()
            rootZone!.displayChildren()
        }
    }


    func setupDatabaseFavorites() {
        if databaseRootFavorites.count == 0 {
            for (index, mode) in databaseModes.enumerated() {
                let          name = mode.rawValue
                let      favorite = create(withBookmark: nil, .addFavorite, parent: databaseRootFavorites, atIndex: index, name)
                favorite.zoneLink =  "\(name)\(gSeparatorKey)\(gSeparatorKey)"
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

            for iProgeny in workingFavorites {
                if  let t = iProgeny.bookmarkTarget, t.isRoot, !t.isTrash {
                    iProgeny.orphan()
                }
            }

            /////////////////////////////////////////////////////
            // look for trash bookmarks and remove all but one //
            /////////////////////////////////////////////////////

            for (index, favorite) in workingFavorites.enumerated() {
                if  let link  = favorite.zoneLink {
                    if  link == gTrashLink {
                        if  foundTrash {
                            trashCopies.append(index)
                        } else {
                            foundTrash = true
                        }
                    } else if let mode = favorite.crossLink?.storageMode,
                        !foundModes.contains(mode) {
                        foundModes.append(mode)
                    }
                }
            }

            while let index = trashCopies.last {
                trashCopies.removeLast()

                if  let trash = zoneAtIndex(index) {
                    trash.orphan()
                    trash.unregister()
                }
            }

            ////////////////////////////////
            // add missing root favorites //
            ////////////////////////////////

            for favorite in databaseRootFavorites.children {
                if  let mode = favorite.crossLink?.storageMode, !foundModes.contains(mode) {
                    let  add = favorite.deepCopy()

                    rootZone?.add(add)
                    add.clearAllStates() // erase side-effect of add
                }
            }

            ////////////////////////////////
            // add missing trash favorite //
            ////////////////////////////////

            if !foundTrash && gTrash != nil {
                let      trash = createBookmark(for: gTrash!, style: .addFavorite)
                trash.zoneLink = gTrashLink
                trash   .order = 0.99999

                trash.clearAllStates()
                trash.needSave()
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
                currentFavorite = bookmark

                bookmark.parentZone?.displayChildren()
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


    @discardableResult func create(withBookmark: Zone?, _ name: String?) -> Zone {
        let bookmark: Zone = withBookmark ?? Zone(storageMode: .mineMode)
        bookmark.zoneName  = name

        return bookmark
    }


    @discardableResult func create(withBookmark: Zone?, _ style: ZFavoriteStyle, parent: Zone, atIndex: Int, _ name: String?) -> Zone {
        let bookmark: Zone = create(withBookmark: withBookmark, name)
        let insertAt: Int? = atIndex == parent.count ? nil : atIndex

        if style != .favorite {
            parent.add(bookmark, at: insertAt) // calls update progeny count
        }
        
        bookmark.updateRecordProperties() // is this needed?

        return bookmark
    }


    @discardableResult func createBookmark(for iZone: Zone, style: ZFavoriteStyle) -> Zone {
        var parent: Zone = iZone.parentZone ?? rootZone!
        let     isNormal = style == .normal

        if  !isNormal {
            let basis: ZRecord = !iZone.isBookmark ? iZone : iZone.crossLink!

            if  let recordName = basis.record?.recordID.recordName {
                parent         = rootZone!

                for bookmark in workingFavorites {
                    if recordName == bookmark.crossLink?.record.recordID.recordName, !bookmark.bookmarkTarget!.isRoot {
                        currentFavorite = bookmark

                        return bookmark
                    }
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

        bookmark?.needSave()

        if  isNormal {
            parent.maybeNeedMerge()
            parent.updateRecordProperties()
        }

        if !iZone.isBookmark {
            bookmark?.crossLink = iZone
        }

        return bookmark!
    }


    // MARK:- toggle
    // MARK:-


    func isWorkingFavorite(_ zone: Zone) -> Bool {
        if  let     recordName  = zone.record?.recordID.recordName {
            for iChild in workingFavorites {
                if  recordName == iChild.crossLink?.record.recordID.recordName {
                    return true
                }
            }
        }

        return false
    }


    func toggleFavorite(for zone: Zone) {
        if  gHasPrivateDatabase && !zone.isRoot {
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
