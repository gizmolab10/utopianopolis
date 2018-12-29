//
//  ZFavoritesManager.swift
//  Thoughtful
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


let gFavorites = ZFavorites()


class ZFavorites: NSObject {


    // MARK:- initialization
    // MARK:-


    let databaseRootFavorites = Zone(record: nil, databaseID: nil)
    var      workingFavorites = [Zone] ()
    var        favoritesIndex : Int { return indexOf(currentFavoriteID) ?? 0 }
    var                 count : Int { return gFavoritesRoot?.count ?? 0 }


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
        var               found: Zone?

        if  let                 target = iTarget,
            let                   dbID = target.databaseID,
            let                   name = target.recordName {
            var                  level = Int.max

            for favorite in workingFavorites {
                if  let favoriteTarget = favorite.bookmarkTarget,
                    let       targetID = favoriteTarget.databaseID,
                    targetID          == dbID {

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


    func setup(_ onCompletion: IntClosure?) {
        let   mine = gMineCloud
        let finish = {
            self.createRootFavorites()

            if  let root = mine?.favoritesZone {
                root.needProgeny()
            }

            onCompletion?(0)
        }

        if  let root = mine?.maybeZoneForRecordName(kFavoritesRootName) {
            mine?.favoritesZone = root

            finish()
        } else {
            mine?.assureRecordExists(withRecordID: CKRecord.ID(recordName: kFavoritesRootName), recordType: kZoneType) { (iRecord: CKRecord?) in
                let       ckRecord = iRecord ?? CKRecord(recordType: kZoneType, recordID: CKRecord.ID(recordName: kFavoritesRootName))
                let           root = Zone(record: ckRecord, databaseID: .mineID)
                root.directAccess  = .eProgenyWritable
                root.zoneName      = kFavoritesName
                mine?.favoritesZone = root

                finish()
            }
        }
    }


    func createRootFavorites() {
        if  databaseRootFavorites.count == 0 {
            for (index, dbID) in kAllDatabaseIDs.enumerated() {
                let          name = dbID.rawValue
                let      favorite = create(withBookmark: nil, .addFavorite, parent: databaseRootFavorites, atIndex: index, name, identifier: name + kFavoritesSuffix)
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

        gFavoritesRoot?.traverseAllProgeny { iChild in
            if iChild.isBookmark {
                self.workingFavorites.append(iChild)
            }
        }
    }


    @discardableResult func updateFavorites() -> Bool {

        ////////////////////////////////////////////////
        // assure at least one root favorite per db   //
        // call every time favorites MIGHT be altered //
        ////////////////////////////////////////////////

        var   hasDatabaseIDs = [ZDatabaseID] ()
        var         discards = IndexPath()
        var      testedSoFar = [Zone] ()
        var      missingLost = true
        var     missingTrash = true
        var     hasDuplicate = false

        updateWorkingFavorites()

        /////////////////////////////////////
        // detect ids which have bookmarks //
        //   remove unfetched duplicates   //
        /////////////////////////////////////

        for favorite in workingFavorites {
            if  let            link  = favorite.zoneLink { // always true: all working favorites have a zone link
                if             link == kTrashLink {
                    if  missingTrash {
                        missingTrash = false
                    } else {
                        hasDuplicate = true
                    }
                } else if  link == kLostAndFoundLink {
                    if  missingLost {
                        missingLost  = false
                    } else {
                        hasDuplicate = true
                    }
                } else if let      t = favorite.bookmarkTarget, t.isRoot,
                    let         dbID = t.databaseID {
                    if !hasDatabaseIDs.contains(dbID) {
                        hasDatabaseIDs.append(dbID)
                    } else {
                        hasDuplicate = true
                    }
                } else {    // target is not a root -> don't bother adding to testedSoFar
                    continue
                }

                //////////////////////////////////////////
                // mark to discard unfetched duplicates //
                //////////////////////////////////////////

                if  hasDuplicate {
                    let isUnfetched: ZoneClosure = { iZone in
                        if iZone.notFetched, let index = self.workingFavorites.index(of: iZone) {
                            discards.append(index)
                        }
                    }

                    for     duplicate in testedSoFar {
                        if  duplicate.bookmarkTarget == favorite.bookmarkTarget {
                            isUnfetched(favorite)
                            isUnfetched(duplicate)

                            break
                        }
                    }
                }

                testedSoFar.append(favorite)
            }
        }

        ///////////////////////////////
        // discard marked duplicates //
        ///////////////////////////////

        while   let   index = discards.popLast() {
            if  let discard = zoneAtIndex(index) {
                discard.needDestroy()
                discard.orphan()
            }
        }

        /////////////////////////////////////////////////
        // add missing trash + lost and found favorite //
        /////////////////////////////////////////////////

        if  missingTrash {
            let          trash = Zone(databaseID: .mineID, named: kTrashName, identifier: kTrashName + kFavoritesSuffix)
            trash    .zoneLink = kTrashLink // convert into a bookmark
            trash.directAccess = .eProgenyWritable

            gFavoritesRoot?.addAndReorderChild(trash)
            trash.clearAllStates()
            trash.markNotFetched()
        }

        if  missingLost {
            let identifier = kLostAndFoundName + kFavoritesSuffix
            var       lost = gMineCloud?.maybeZoneForRecordName(identifier)

            if  lost      == nil {
                lost       = Zone(databaseID: .mineID, named: kLostAndFoundName, identifier: identifier)
            }

            lost?    .zoneLink = kLostAndFoundLink // convert into a bookmark
            lost?.directAccess = .eProgenyWritable

            gFavoritesRoot?.addAndReorderChild(lost!)
            lost?.clearAllStates()
            lost?.markNotFetched()
        }

        ////////////////////////////////
        // add missing root favorites //
        ////////////////////////////////

        for template in databaseRootFavorites.children {
            if  let          dbID = template.linkDatabaseID, !hasDatabaseIDs.contains(dbID) {
                let      favorite = template.deepCopy
                favorite.zoneName = favorite.bookmarkTarget?.zoneName

                gFavoritesRoot?.addChildAndRespectOrder(favorite)
                favorite.clearAllStates() // erase side-effect of add
                favorite.markNotFetched()
            }
        }

        updateWorkingFavorites()
        updateCurrentFavorite()
        
        return missingLost || missingTrash || hasDuplicate
    }


    func updateCurrentFavorite(reveal: Bool = false) {
        if  let     favorite = favorite(for: gHere),
            let       target = favorite.bookmarkTarget,
            (gHere == target || !hereSpawnedTargetOfCurrentFavorite) {
            currentFavorite = favorite

            if  reveal {

                //////////////////////////////////////////////////////////////////
                // not reveal current favorite if user has hidden all favorites //
                //////////////////////////////////////////////////////////////////

                favorite.traverseAllAncestors { iAncestor in
                    iAncestor.revealChildren()
                }
            }
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

            if !gFocusing.focus(through: zone, atArrival) {
                bump?(self.next(iIndex, forward))
            }
        }

        bump?(index)
    }


    @discardableResult func refocus(_ atArrival: @escaping Closure) -> Bool {
        if  let favorite = currentFavorite {
            return gFocusing.focus(through: favorite, atArrival)
        }

        return false
    }


    // MARK:- create
    // MARK:-


    @discardableResult func create(withBookmark: Zone?, _ iName: String?, identifier: String? = nil) -> Zone {
        var           bookmark = withBookmark
        if  bookmark          == nil {
            bookmark           = Zone(databaseID: .mineID, named: iName, identifier: identifier)
        } else if let     name = iName {
            bookmark!.zoneName = name
        }

        return bookmark!
    }


    @discardableResult func create(withBookmark: Zone?, _ style: ZFavoriteStyle, parent: Zone, atIndex: Int, _ name: String?, identifier: String? = nil) -> Zone {
        let bookmark: Zone = create(withBookmark: withBookmark, name, identifier: identifier)
        let insertAt: Int? = atIndex == parent.count ? nil : atIndex

        if  style != .favorite {
            parent.addChild(bookmark, at: insertAt) // calls update progeny count
        }
        
        bookmark.updateCKRecordProperties() // is this needed?

        return bookmark
    }


    @discardableResult func createBookmark(for iZone: Zone, style: ZFavoriteStyle) -> Zone {
        var parent: Zone = iZone.parentZone ?? gFavoritesRoot!
        let   isBookmark = iZone.isBookmark
        let     isNormal = style == .normal

        if  !isNormal {
            let basis: ZRecord = isBookmark ? iZone.crossLink! : iZone

            if  let recordName = basis.recordName {
                parent         = gFavoritesRoot!

                for bookmark in workingFavorites {
                    if  recordName == bookmark.linkRecordName, !bookmark.bookmarkTarget!.isRoot {
                        currentFavorite = bookmark

                        return bookmark
                    }
                }
            }
        }

        let           count = parent.count
        var bookmark: Zone? = isBookmark ? iZone.deepCopy : nil
        var           index = parent.children.index(of: iZone) ?? count

        if  style == .addFavorite {
            index           = nextFavoritesIndex(forward: gInsertionsFollow)
        }

        bookmark            = create(withBookmark: bookmark, style, parent: parent, atIndex: index, iZone.zoneName)

        bookmark?.maybeNeedSave()

        if  isNormal {
            parent.updateCKRecordProperties()
            parent.maybeNeedMerge()
        }

        if !isBookmark {
            bookmark?.crossLink = iZone

            gBookmarks.registerBookmark(bookmark!)
        }

        return bookmark!
    }


    // MARK:- toggle
    // MARK:-


    func isWorkingFavorite(_ iZone: Zone) -> Bool {
        for     iChild in workingFavorites {
            if  iChild == iZone || iChild.bookmarkTarget == iZone {
                return true
            }
        }

        return false
    }


    func toggleFavorite(for zone: Zone) {
        if  isWorkingFavorite  (zone) {
            deleteFavorite(for: zone)
        } else {
            createBookmark(for: zone, style: .addFavorite)
        }

        updateFavorites()
    }


    func deleteFavorite(for zone: Zone) {
        let recordID = zone.record?.recordID

        for favorite in workingFavorites {
            if  favorite.crossLink?.record?.recordID == recordID {
                favorite.needDestroy()
                favorite.orphan()

                gBookmarks.unregisterBookmark(favorite)

                return
            }
        }
    }

}
