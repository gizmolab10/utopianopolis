//
//  ZFavorites.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/24/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit

let gFavoritesCloud     = ZFavorites(ZDatabaseID.favoritesID)
var gFavoritesRoot : Zone? { return gFavoritesCloud.rootZone }
var gFavoritesHere : Zone? { return gFavoritesHereMaybe ?? gFavoritesRoot }

var gFavoritesHereMaybe: Zone? {
	get { return gHereZoneForDatabaseIDMaybe(       .favoritesID) }
	set { gSetHereZoneForDatabaseID(here: newValue, .favoritesID) }
}

class ZFavorites: ZRecords {

	var rootsMaybe       : Zone?
	var otherCurrent     : Zone?
	var recentsMaybe     : Zone?
	var recentCurrent    : Zone?
	var currentlyPopping : Zone?
	var workingBookmarks : ZoneArray { return (gBrowsingIsConfined ? hereZoneMaybe?.bookmarks : rootZone?.bookmarks) ?? [] }

	var hasMultipleNotes : Bool {
		if  let    zones = gBrowsingIsConfined ? hereZoneMaybe?.notemarks : rootZone?.notemarks {
			return zones.count > 1
		}

		return false
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

	@discardableResult func getRecentsGroup() -> Zone {
		guard let   zone = recentsMaybe else {
			recentsMaybe = getOrSetupGroup(with: kRecentsName)

			return recentsMaybe!
		}

		return zone
	}

	func getOrSetupGroup(with name: String) -> Zone {
		if  let all = rootZone?.allProgeny {
			for zone in all {
				if  zone.recordName == name {
					return zone
				}
			}
		}

		// ///////////////// //
		// add missing group //
		// ///////////////// //

		let          group = Zone.uniqueZone(recordName: name, in: .mineID)
		group     .mapType = .tFavorite
		group    .zoneName = name
		group.directAccess = .eReadOnly

		group.collapse()
		group.register()
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
			rootZone = rootZone ?? Zone.uniqueZone(recordName: kFavoritesRootName, in: .mineID, checkCDStore: true)

			updateAllFavorites() // setup roots group

			if  gCDMigrationState == .mFirstTime {
				hereZoneMaybe = getRecentsGroup()
			}

			push(gHereZoneForDatabaseIDMaybe(gDatabaseID))
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

		return bookmarkToMove(is: gSelecting.currentMoveableMaybe) ?? bookmarkToMove(is: otherCurrent)
	}

	var allGroups: ZoneArray? {
		if  var zones = rootZone?.allGroups {
			zones.appendUnique(item: rootZone)
			return zones
		}

		return nil
	}

	var hideDownButton: Bool {
		if  let zones = allGroups {
			return zones.count < 3
		}

		return true
	}

	var hideUpDownView: Bool {
		if  let zones = allGroups {
			return zones.count < 2
		}

		return true
	}

	func targeting(_ target: Zone, in array: ZoneArray?, orSpawnsIt: Bool = true) -> ZoneArray? {
		return array?.whoseTargetIntersects(with: [target], orSpawnsIt: orSpawnsIt)
	}

	func workingBookmarks(for target: Zone) -> ZoneArray? {
		return targeting(target, in: workingBookmarks, orSpawnsIt: false)
	}

	func recentsTargeting(_ target: Zone, orSpawnsIt: Bool = false) -> ZoneArray? {
		return targeting(target, in: getRecentsGroup().children, orSpawnsIt: orSpawnsIt)
	}

	func favoritesTargeting(_ target: Zone, orSpawnsIt: Bool = false) -> ZoneArray? {
		return targeting(target, in: rootZone?.bookmarks, orSpawnsIt: orSpawnsIt)
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
		if  let    current = otherCurrent ?? recentCurrent {
			return current.focusThrough(atArrival)
		}

		atArrival()

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
		if  let bookmarks = rootZone?.bookmarks.intersection(zone.bookmarksTargetingSelf), bookmarks.count > 0,
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

		// ////////////////////////////////////////// //
		// assure at least one root favorite per db   //
		// call every time favorites MIGHT be altered //
		// ////////////////////////////////////////// //

		if  let           root = rootZone {
			let          zones = root.all
			var hasDatabaseIDs = ZDatabaseIDArray()
			var       discards = IndexPath()
			var    testedSoFar = ZoneArray()
			var missingRecents = true
			var missingDestroy = true
			var   missingTrash = true
			var    missingLost = true

			// /////////////////////////////// //
			// detect ids which have bookmarks //
			//   remove unfetched duplicates   //
			// /////////////////////////////// //

			for zone in zones {
				if !zone.isBookmark {
					if  zone    .recordName == kRecentsName {
						missingRecents       = false
					}
				} else {
					let             bookmark = zone
					var         hasDuplicate = false

					if  let            link  = bookmark.zoneLink?.maybeRecordName {     // always true: all bookmarks have a zone link
						if             link == kTrashName {
							if  missingTrash {
								missingTrash = false
							} else {
								hasDuplicate = true
							}
						} else if      link == kLostAndFoundName {
							if  missingLost {
								missingLost  = false
							} else {
								hasDuplicate = true
							}
						} else if        link == kDestroyName {
							if  missingDestroy {
								missingDestroy = false
							} else {
								hasDuplicate   = true
							}
						} else if let     databaseID = bookmark.linkDatabaseID, bookmark.linkIsRoot,
								  let        p = bookmark.parentZone, p == getRootsGroup() {
							if !hasDatabaseIDs.contains(databaseID) {
								hasDatabaseIDs.append(databaseID)
							} else {
								hasDuplicate   = true
							}
						} else {    // target is not a root -> don't bother adding to testedSoFar
							continue
						}

						// //////////////////////////////////// //
						// mark to discard unfetched duplicates //
						// //////////////////////////////////// //

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
			}

			// ///////////////////////// //
			// discard marked duplicates //
			// ///////////////////////// //

			while   let   index = discards.popLast() {
				if  index       < workingBookmarks.count {
					let discard = workingBookmarks[index]

					discard.needDestroy()
					discard.orphan()
					discard.deleteFromCD()
				}
			}

			for databaseID in kAllDatabaseIDs {
				if !hasDatabaseIDs.contains(databaseID) {
					let        dbName = databaseID.rawValue
					let      bookmark = Zone.uniqueZone(recordName: dbName + kFavoritesSuffix, in: .mineID, checkCDStore: true)
					bookmark.zoneLink = dbName + kDoubleColonSeparator
					bookmark.zoneName = bookmark.bookmarkTarget?.zoneName ?? dbName

					getRootsGroup().addChildAndUpdateOrder(bookmark)
					gRelationships.addBookmarkRelationship(for: bookmark, targetNamed: dbName + kDoubleColonSeparator + kRootName, in: databaseID)
				}
			}

			func createRootsBookmark(named: String) {
				let      bookmark = Zone.uniqueZone(recordName: named + kFavoritesSuffix, in: .mineID, checkCDStore: true)
				bookmark.zoneLink = kDoubleColonSeparator + named                           // convert into a bookmark
				bookmark.zoneName = named

				if  gBookmarks.addToReverseLookup(bookmark) {
					gRelationships.addBookmarkRelationship(for: bookmark, targetNamed: kDoubleColonSeparator + named, in: .mineID)
				}

				getRootsGroup().addChildAndUpdateOrder(bookmark)
			}

			// //////////////////// //
			// add missing defaults //
			// //////////////////// //

			if  missingRecents {
				getRecentsGroup()
			}

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

	// MARK: - focus
	// MARK: -

	func revealBookmark(of target: Zone) {

		// locate and make bookmark of target visible and mark it

		if  let bookmarks = favoritesTargeting(target, orSpawnsIt: false) {
			for bookmark in bookmarks {
				revealAndMarkInFavoritesMap(bookmark)
			}
		}
	}

	func revealInFavoritesMap(_    iZone: Zone? = nil) {
		if  let zone         = iZone {
			if  let parent   = zone.parentZone,
				currentHere != parent {
				let here     = currentHere
				currentHere  = parent

				here.collapse()
			}

			currentHere.expand()
		}
	}

	func revealAndMarkInFavoritesMap(_  iZone: Zone? = nil) {
		revealInFavoritesMap(iZone)
		setCurrentFavoriteBoomkarks(to: iZone)
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
						recentCurrent  = bookmark
					}
				} else if !markedFavorite, !inRecents {
					otherCurrent    = bookmark

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
		if  let cb = otherCurrent,
			cb.isGrabbed {            // grabbed in favorites map, so ...
			cb.bookmarkTarget?.grab() // grab target in main map
		} else if doNotGrab {
			return false
		} else {
			for bookmark in gHere.bookmarksTargetingSelf {
				let isInHere = bookmark.isInFavoritesHere

				if !bookmark.isDeleted, flags.hasCommand ? bookmark.isInRecentsGroup : isInHere {
					gShowDetailsView = true

					if  !isInHere {
						revealAndMarkInFavoritesMap(bookmark)
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
