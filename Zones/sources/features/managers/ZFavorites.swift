//
//  ZFavorites.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/24/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit

let gFavorites     = ZFavorites(ZDatabaseID.favoritesID)
var gFavoritesRoot : Zone? { return gFavorites.rootZone }
var gFavoritesHere : Zone? { return gFavoritesHereMaybe ?? gFavoritesRoot }

var gFavoritesHereMaybe: Zone? {
	get { return gHereZoneForIDMaybe(       .favoritesID) }
	set { gSetHereZoneForID(here: newValue, .favoritesID) }
}

func gSetHereZoneForID(here: Zone?, _ dbID: ZDatabaseID) {
	gRemoteStorage.zRecords(for: dbID)?.hereZoneMaybe = here
}

func gHereZoneForIDMaybe(_ dbID: ZDatabaseID) -> Zone? {
	if  let    cloud = gRemoteStorage.zRecords(for: dbID) {
		return cloud.maybeZoneForRecordName(cloud.hereRecordName, trackMissing: false)
	}

	return nil
}

class ZFavorites: ZRecords {

	var currentFavorite  : Zone?
	var currentRecent    : Zone?
	var recentsMaybe     : Zone?
	var rootsMaybe       : Zone?
	var working          : ZoneArray { return  gIsEssayMode ? workingNotemarks : workingBookmarks }
	var workingGroups    : ZoneArray { return  rootZone?.allGroups ?? [] }
	var workingBookmarks : ZoneArray { return (gBrowsingIsConfined ? hereZoneMaybe?.bookmarks : rootZone?.bookmarks) ?? [] }
	var workingNotemarks : ZoneArray { return (gBrowsingIsConfined ? hereZoneMaybe?.notemarks : rootZone?.notemarks) ?? [] }

	func working(amongNotes: Bool = false, withinRecents: Bool = true) -> ZoneArray? {
		let root = withinRecents ? getRecentsGroup() : rootZone

		return amongNotes ? root?.bookmarks : root?.notemarks
	}

	// MARK: - initialization
	// MARK: -

	func getRootsGroup() -> Zone {
		guard let zone = rootsMaybe else {
			rootsMaybe = getOrSetupGroup(with: kRootsName)

			return rootsMaybe!
		}

		return zone
	}

	func getRecentsGroup() -> Zone {
		guard let   zone = recentsMaybe else {
			recentsMaybe = getOrSetupGroup(with: kRecentsName)

			return recentsMaybe!
		}

		return zone
	}

	func getOrSetupGroup(with name: String) -> Zone {
		for zone in all {
			if  zone.recordName == name {
				return zone
			}
		}

		// ///////////////// //
		// add missing group //
		// ///////////////// //

		let          group = Zone.uniqueZone(recordName: name, in: .mineID)
		group    .zoneName = name
		group.directAccess = .eReadOnly

		group.collapse()
		group.alterAttribute(.groupOwner, remove: false)
		gFavoritesRoot?.addChildAndRespectOrder(group)

		return group
	}

	var hasTrash: Bool {
		for favorite in workingBookmarks {
			if  let target = favorite.bookmarkTarget, target.isTrashRoot {
				return true
			}
		}

		return false
	}

	override var rootZone : Zone? {
		get {
			return gMineCloud?.favoritesZone
		}

		set {
			gMineCloud?.favoritesZone = newValue
		}
	}

	func setup(_ onCompletion: IntClosure?) {
		FOREGROUND { [self] in               // avoid error? mutating core data while enumerating
			rootZone = rootZone ?? Zone.uniqueZone(recordName: kFavoritesRootName, in: .mineID)

			updateAllFavorites() // setup roots group

			if  gCDMigrationState == .firstTime {
				hereZoneMaybe = getRootsGroup()
			}

			rootZone?.concealAllProgeny()
			hereZoneMaybe?.expand()
			onCompletion?(0)
		}
	}

	@discardableResult func matchOrCreateBookmark(for zone: Zone, addToRecents: Bool) -> Zone {
		if  zone.isBookmark, let root = rootZone, zone.root == root {
			return zone
		}

		let           target = zone.bookmarkTarget ?? zone
		if  let    bookmarks = favoritesTargeting(target), bookmarks.count > 0 {
			return bookmarks[0]
		}

		return ZBookmarks.newOrExistingBookmark(targeting: zone, addTo: addToRecents ? getRecentsGroup() : nil)
	}

    // MARK: - mutate
    // MARK: -

	var bookmarkToMove: Zone? {

		func bookmarkToMove(is bookmark: Zone?) -> Zone? {
			if  let b = bookmark,
				let p = b.parentZone, p == hereZoneMaybe {
				return b
			}

			return nil
		}

		return bookmarkToMove(is: gSelecting.currentMoveableMaybe) ?? bookmarkToMove(is: currentFavorite)
	}

	var allGroups: ZoneArray? {
		if  var zones = rootZone?.allGroups {
			zones.appendUnique(item: rootZone)
			return zones
		}

		return nil
	}

	var hideUpDownView: Bool {
		if  let zones = allGroups {
			return zones.count < 1
		}

		return true
	}

	var current : Zone? {
		if  let here  = hereZoneMaybe {
			if  here == getRecentsGroup() {
				return currentRecent
			}

			return currentFavorite
		}

		return nil
	}

	func isCurrent(_ zone: Zone) -> Bool {
		return [currentRecent, currentFavorite].contains(zone)
	}

	func current(mustBeRecents: Bool = false) -> Zone? {
		let useRecents = mustBeRecents || currentHere.isInRecentsGroup

		return useRecents ? currentRecent : currentFavorite
	}

	func setCurrent(_ zone: Zone?, mustBeRecents: Bool = false) {
		currentRecent = zone

		if !mustBeRecents, !currentHere.isInRecentsGroup, !(zone?.isInRecentsGroup ?? false) {
			currentFavorite = zone
		}
	}

	func maybeSetCurrentWithinHere(_ zone: Zone) -> Bool {
		if  let here = hereZoneMaybe, zone.isProgenyOf(here) {
			if  here.isInRecentsGroup {
				currentRecent   = zone
			} else {
				currentFavorite = zone
			}

			return true
		}

		return false // current was not altered
	}

	func moveCurrentTo(_ zone: Zone) {
		if  let parent = zone.parentZone,
			let      p = currentFavorite?.parentZone, p == parent,
			let   from = currentFavorite?.siblingIndex,
			let     to = zone.siblingIndex {
			parent.moveChildIndex(from: from, to: to)
		}
	}

	func setCurrentBookmarksTargeting(_ zone: Zone) {
		for bookmark in zone.bookmarksTargetingSelf {
			setCurrent(bookmark)
		}
	}

	func setAsCurrent(_ zone: Zone?, alterBigMapFocus: Bool = false, makeVisible: Bool = false) {
		if  makeVisible {
			makeVisibleAndMarkInSmallMap(zone)
		}

		if  let target = zone?.bookmarkTarget {
			setCurrentBookmarksTargeting(target)

			if  alterBigMapFocus {
				gDatabaseID          = target.databaseID
				gRecords.currentHere = target // avoid push

				target.grab()
				push(target)
			}

			if  gIsMapMode {
				gFocusing.focusOnGrab(.eSelected) {
					gSignal([.spCrumbs, .spRelayout, .spDataDetails])
				}
			} else if gCurrentEssayZone != target {
				gEssayView?.resetCurrentEssay(target.note)
				gSignal([.spCrumbs, .sDetails])
			}
		}
	}

	func targeting(_ target: Zone, in array: ZoneArray?, orSpawnsIt: Bool = true) -> ZoneArray? {
		return array?.whoseTargetIntersects(with: [target], orSpawnsIt: orSpawnsIt)
	}

	func workingBookmarks(for target: Zone) -> ZoneArray? {
		return targeting(target, in: workingBookmarks, orSpawnsIt: false)
	}

	func favoritesTargeting(_ target: Zone, orSpawnsIt: Bool = false) -> ZoneArray? {
		return targeting(target, in: rootZone?.bookmarks, orSpawnsIt: orSpawnsIt)
	}

	func recentsTargeting(_ target: Zone, orSpawnsIt: Bool = false) -> ZoneArray? {
		return targeting(target, in: getRecentsGroup().bookmarks, orSpawnsIt: orSpawnsIt)
	}

	func object(for id: String) -> NSObject? {
		let parts = id.components(separatedBy: kColonSeparator)

		if  parts.count == 2 {
			if  parts[0] == "note" {
				return ZNote .object(for: parts[1], isExpanded: false)
			} else {
				return ZEssay.object(for: parts[1], isExpanded: true)
			}
		}

		return nil
	}

	@discardableResult func refocus(_ atArrival: @escaping Closure) -> Bool {
		if  let    current = currentFavorite {
			return current.focusThrough(atArrival)
		}

		return false
	}

	func setHere(to zone: Zone?) {
		if  let here = zone {
			rootZone?.concealAllProgeny()

			hereZoneMaybe = here

			here.expand()
		}
	}

	func show(_ zone: Zone) {
		let bookmarks = all.intersection(zone.bookmarksTargetingSelf)
		if  bookmarks.count > 0,
			let parent = bookmarks[0].parentZone {
			setHere(to: parent)
		}
	}

	func showRoot() { setHere(to: rootZone) }

	// MARK: - update
	// MARK: -
    
    func updateFavoritesAndRedraw(needsRedraw: Bool = true, _ onCompletion: Closure? = nil) {
        if  !updateAllFavorites(), !needsRedraw {
			gFavoritesMapController.replaceAllToolTips(gModifierFlags)
        }

		if  needsRedraw {
			gRelayoutMaps()
		}

		onCompletion?()
    }

    @discardableResult func updateAllFavorites() -> Bool {
		var result = false

		// /////////////////////////////////////////////
		// assure at least one root favorite per db   //
		// call every time favorites MIGHT be altered //
		// /////////////////////////////////////////////

		if  let      bookmarks = rootZone?.bookmarks {
			var hasDatabaseIDs = [ZDatabaseID] ()
			var       discards = IndexPath()
			var    testedSoFar = ZoneArray ()
			var missingDestroy = true
			var   missingTrash = true
			var    missingLost = true

			// //////////////////////////////////
			// detect ids which have bookmarks //
			//   remove unfetched duplicates   //
			// //////////////////////////////////

			for bookmark in bookmarks {
				var         hasDuplicate = false
				if  let            link  = bookmark.zoneLink {     // always true: all bookmarks have a zone link
					if             link == kTrashLink {
						if  missingTrash {
							missingTrash = false
						} else {
							hasDuplicate = true
						}
					} else if      link == kLostAndFoundLink {
						if  missingLost {
							missingLost  = false
						} else {
							hasDuplicate = true
						}
					} else if        link == kDestroyLink {
						if  missingDestroy {
							missingDestroy = false
						} else {
							hasDuplicate   = true
						}
					} else if let     dbID = bookmark.linkDatabaseID, bookmark.linkIsRoot,
							  let        p = bookmark.parentZone, p == getRootsGroup() {
						if !hasDatabaseIDs.contains(dbID) {
							hasDatabaseIDs.append(dbID)
						} else {
							hasDuplicate   = true
						}
					} else {    // target is not a root -> don't bother adding to testedSoFar
						continue
					}

					// ///////////////////////////////////////
					// mark to discard unfetched duplicates //
					// ///////////////////////////////////////

					if  hasDuplicate {
						let isUnfetched: ZoneClosure = { [self] iZone in
							if  let index = workingBookmarks.firstIndex(of: iZone) {
								discards.append(index)
							}
						}

						for     duplicate in testedSoFar {
							if  duplicate.bookmarkTarget == bookmark.bookmarkTarget {
								isUnfetched(bookmark)
								isUnfetched(duplicate)

								break
							}
						}
					}

					testedSoFar.append(bookmark)
				}
			}

			// ////////////////////////////
			// discard marked duplicates //
			// ////////////////////////////

			while   let   index = discards.popLast() {
				if  index < workingBookmarks.count {
					let discard = workingBookmarks[index]
					discard.needDestroy()
					discard.orphan()
					gCDCurrentBackgroundContext.delete(discard)
				}
			}

			for dbID in kAllDatabaseIDs {
				if !hasDatabaseIDs.contains(dbID) {
					let          name = dbID.rawValue
					let      bookmark = Zone.uniqueZone(recordName: name + kFavoritesSuffix, in: .mineID)
					bookmark.zoneLink = name + kColonSeparator + kColonSeparator
					bookmark.zoneName = bookmark.bookmarkTarget?.zoneName ?? name

					getRootsGroup().addChildAndUpdateOrder(bookmark)
				}
			}

			func createRootsBookmark(named: String) {
				let      bookmark = Zone.uniqueZone(recordName: named + kFavoritesSuffix, in: .mineID)
				bookmark.zoneLink = kColonSeparator + kColonSeparator + named                           // convert into a bookmark
				bookmark.zoneName = named

				getRootsGroup().addChildAndUpdateOrder(bookmark)
			}

			// //////////////////////////////////////////////
			// add missing trash + lost and found favorite //
			// //////////////////////////////////////////////

			if  missingTrash {
				createRootsBookmark(named: kTrashName)
			}

			if  missingLost {
				createRootsBookmark(named: kLostAndFoundName)
			}

			if  missingDestroy && gAddDestroy {
				createRootsBookmark(named: kDestroyName)
			}

			for zone in getRootsGroup().children {
				zone.directAccess = .eReadOnly
			}

			result = missingLost || missingTrash || (missingDestroy && gAddDestroy)
		}

		return result
	}

	// MARK: - cycle
	// MARK: -

	func nextBookmark(down: Bool, flags: ZEventFlags) {
		let COMMAND = flags.hasCommand
		let  OPTION = flags.hasOption
		let   SHIFT = flags.hasShift

		if  COMMAND {
			showNextList(down: down, moveCurrent: OPTION)
		} else {
			nextBookmark(down: down, moveCurrent: OPTION, withinRecents: SHIFT)
		}
	}

	func nextList(down: Bool) -> Zone? {
		if  let  here = hereZoneMaybe,
			let zones = allGroups {
			let index = zones.firstIndex(of: here) ?? 0
			if  let n = index.next(forward: down, max: zones.count - 1) {
				return zones[n]
			}
		}

		return rootZone
	}

	func nextListAttributed(down: Bool) -> NSAttributedString {
		let string = nextList(down: down)?.unwrappedName.capitalized ?? kEmpty

		return string.darkAdaptedTitle
	}

	@discardableResult func showNextList(down: Bool, moveCurrent: Bool = false) -> Zone? {
		if  let  here = nextList(down: down) {
			if  let b = bookmarkToMove, moveCurrent {
				b.moveZone(to: here)
			}

			setHere(to: here)
			gSignal([.spCrumbs, .spSmallMap])

			return here
		}

		return nil
	}

	func nextBookmark(down: Bool, amongNotes: Bool = false, moveCurrent: Bool = false, withinRecents: Bool = true) {
		var current   = current(mustBeRecents: withinRecents)
		if  current  == nil {
			current   = push()
		}
		if  let  root = withinRecents ? getRecentsGroup() : rootZone {
			let zones = amongNotes    ? root.notemarks   : root.bookmarks
			let count = zones.count
			if  count > 1 {           // there is no next for count == 0 or 1
				let    maxIndex = zones.count - (moveCurrent ? 2 : 1)
				var     toIndex = down ? maxIndex : 0
				if  let  target = current?.zoneLink {
					for (index, bookmark) in zones.enumerated() {
						if  target       == bookmark.zoneLink,
							var next      = index.next(forward: down, max: maxIndex) {
							while    !zones[next].isBookmark {
								if  let m = next .next(forward: down, max: maxIndex) {
									next  = m
								} else {
									break
								}
							}

							toIndex       = next
						}
					}

					if  toIndex.isWithin(0 ... maxIndex) {
						let  newCurrent = zones[toIndex]
						if  moveCurrent {
							moveCurrentTo(newCurrent)
						} else {
							setAsCurrent (newCurrent, alterBigMapFocus: !amongNotes, makeVisible: false)
						}
					}
				}
			}
		}
	}

	// MARK: - pop and push
	// MARK: -

	func resetRecents() {
		recentsMaybe = nil // gotta re-traverse recents
	}

	@discardableResult func push(_ zone: Zone? = gHere) -> Zone? {
		if  let    target = zone {
			let   recents = recentsTargeting(target)
			let     index = currentRecent?.nextSiblingIndex
			let      here = getRecentsGroup()
			if  let exant = recents?.firstUndeleted,
				maybeSetCurrentWithinHere(exant) {

				return exant
			}

			let  bookmark = ZBookmarks.newBookmark(targeting: target)

			here.addChildNoDuplicate(bookmark, at: index)
			gBookmarks.addToReverseLookup(bookmark)
			setCurrent(bookmark)
			resetRecents()

			return bookmark
		}

		return nil
	}

	@discardableResult func pop(_ iZone: Zone? = gHereMaybe) -> Bool {
		if  let zone = iZone {
			if  zone.isInFavorites {
				zone.deleteSelf(permanently: true) { [self] flag in
					if  flag {
						resetRecents()
					}
				}

				return true
			} else if let bookmarks = favoritesTargeting(zone) {
				for bookmark in bookmarks {
					bookmark.deleteSelf(permanently: true) { flag in }
				}

				resetRecents()

				return true
			}
		}

		return false
	}

	func popAndUpdateCurrent() {
		if  let           c = currentRecent ?? currentFavorite,
			let       index = c.siblingIndex,
			let    children = c.siblings,
			let        next = children.next(from: index, forward: gListsGrowDown),
			pop(c) {
			setCurrent(next)

			if  let    here = next.bookmarkTarget {
				gHere       = here

				gHere.grab()
			}
		}

		gSignal([.sDetails])
		gRelayoutMaps()
	}

	func popNoteAndUpdate() -> Bool {
		if  pop(),
			let  notemark = rootZone?.notemarks.first,
			let      note = notemark.bookmarkTarget?.note {
			gCurrentEssay = note

			setAsCurrent(notemark, makeVisible: true)
			gSignal([.spSmallMap, .spCrumbs])

			return true
		}

		return false
	}

	func insertAsNext(_ zone: Zone) {
		if  let           r = rootZone {
			let      cIndex = r.children.firstIndex(of: zone) ?? 0
			let       index = cIndex.next(forward: gListsGrowDown, max: r.count - 1)

			r.addChildNoDuplicate(zone, at: index)
			setCurrent(zone)
		}
	}

	func removeBookmarks(for iZone: Zone? = gHereMaybe) {
		if  let      zone = iZone,
			let bookmarks = workingBookmarks(for: zone) {
			for bookmark in bookmarks {
				bookmark.deleteSelf(permanently: true) { [self] flag in
					resetRecents()
				}
			}
		}
	}

	// MARK: - focus
	// MARK: -

	func revealBookmark(of target: Zone) {

		// locate and make bookmark of target visible and mark it

		if  let bookmarks = favoritesTargeting(target, orSpawnsIt: false) {
			for bookmark in bookmarks {
				makeVisibleAndMarkInSmallMap(bookmark)
			}
		}
	}

	func makeVisibleAndMarkInSmallMap(_  iZone: Zone? = nil) {
		if  let zone         = iZone {
			if  let parent   = zone.parentZone,
				currentHere != parent {
				let here     = currentHere
				currentHere  = parent

				here.collapse()
			}

			currentHere.expand()
			setCurrent(zone)
		}
	}

	var currentTargets: ZoneArray {
		var  targets = ZoneArray()

		if  gIsEssayMode,
			let zone = gCurrentEssayZone {
			targets.append(zone)
		} else if let here = gHereMaybe {
			targets.append(here)

			if  let grab = gSelecting.firstGrab(),
				!targets.contains(grab) {
				targets.append(grab)
			}
		}

		return targets
	}

	var bookmarksTargetingHere: ZoneArray? {
		if  let bookmarks = rootZone?.bookmarks, bookmarks.count > 0 {
			let matches   = bookmarks.whoseTargetIntersects(with: currentTargets, orSpawnsIt: false)
			if  matches.count > 0 {
				return matches
			}
		}

		return nil
	}

	func updateCurrentWithBookmarksTargetingHere() {
		if  let      bookmarks = bookmarksTargetingHere {
			let      inRecents = currentHere.isInRecentsGroup
			var markedRecent   = false
			var markedFavorite = false
			for bookmark in bookmarks {
				let toRecents  = bookmark.isInRecentsGroup
				if  toRecents {
					if !markedRecent {
						markedRecent   = true
						currentRecent  = bookmark
					}
				} else if !markedFavorite, !inRecents {
					currentFavorite    = bookmark

					if  bookmark.isInFavoritesHere {
						markedFavorite = true
					}
				}

				if  markedRecent, markedFavorite {
					return
				}
			}
		}
	}

	func grab(_ zones: ZoneArray) {
		gSelecting.ungrabAll()

		for zone in zones {
			grab(zone, onlyOne: false)
		}
	}

	func grab(_ zone: Zone, onlyOne: Bool = true) {
		if  onlyOne {
			zone.grab()
		} else {
			zone.addToGrabs()
		}

		if  let p = zone.parentZone {
			if  let h = hereZoneMaybe, h != p {
				hereZoneMaybe = p

				h.collapse()
			}

			p.expand()
		}
	}

	@discardableResult func swapBetweenBookmarkAndTarget(_ flags: ZEventFlags = ZEventFlags(), doNotGrab: Bool = true) -> Bool {
		if  let cb = currentFavorite,
			cb.isGrabbed {            // grabbed in small map, so ...
			cb.bookmarkTarget?.grab() // grab target in big map
		} else if doNotGrab {
			return false
		} else {
			let bookmarks = gHere.bookmarksTargetingSelf

			for bookmark in bookmarks {
				let isInHere = bookmark.isInFavoritesHere

				if !bookmark.isDeleted, flags.hasCommand ? bookmark.isInRecentsGroup : isInHere {
					gShowDetailsView = true

					if  !isInHere {
						makeVisibleAndMarkInSmallMap(bookmark)
					}

					bookmark.grab()
					gDetailsController?.showViewFor(.vFavorites)
					gSignal([.spMain, .sDetails, .spRelayout])

					return true
				}
			}

			push()
		}

		return true
	}

}
