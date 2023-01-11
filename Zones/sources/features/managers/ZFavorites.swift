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

class ZFavorites: ZSmallMapRecords {

    // MARK: - initialization
    // MARK: -

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
			if  let n = newValue {
				gMineCloud?.favoritesZone = n
			}
		}
	}

	var rootsGroupZone: Zone {
		for zone in allProgeny {
			if  zone.recordName == kRootsName {
				return zone
			}
		}

		// /////////////////////////
		// add missing root group //
		// /////////////////////////

		let          rootsGroup = Zone.uniqueZone(recordName: kRootsName, in: .mineID)
		rootsGroup    .zoneName = kRootsName
		rootsGroup.directAccess = .eReadOnly

		rootsGroup.alterAttribute(.groupOwner, remove: false)
		gFavoritesRoot?.addChildAndRespectOrder(rootsGroup)

		return rootsGroup
	}

	var recentsGroupZone: Zone {
		for zone in allProgeny {
			if  zone.recordName == kRecentsName {
				return zone
			}
		}

		// /////////////////////////
		// add missing root group //
		// /////////////////////////

		let          recentsGroup = Zone.uniqueZone(recordName: kRecentsName, in: .mineID)
		recentsGroup    .zoneName = kRecentsName
		recentsGroup.directAccess = .eReadOnly

		recentsGroup.collapse()
		recentsGroup.alterAttribute(.groupOwner, remove: false)
		gFavoritesRoot?.addChildAndRespectOrder(recentsGroup)

		return recentsGroup
	}

	func setup(_ onCompletion: IntClosure?) {
		FOREGROUND { [self] in               // avoid error? mutating core data while enumerating
			rootZone = rootZone ?? Zone.uniqueZone(recordName: kFavoritesRootName, in: .mineID)

			updateAllFavorites() // setup roots group

			if  gCDMigrationState == .firstTime {
				hereZoneMaybe = rootsGroupZone
			}

			rootZone?.concealAllProgeny()
			hereZoneMaybe?.expand()
			onCompletion?(0)
		}
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

	var current : Zone? {
		if  let here  = hereZoneMaybe {
			if  here == recentsGroupZone {
				return currentRecent
			}

			return currentFavorite
		}

		return nil
	}

	func maybeSetCurrentWithinHere(_ zone: Zone) -> Bool {
		if  let here = hereZoneMaybe, zone.spawnedBy(here) {
			if  here.isInRecentsGroup {
				currentRecent   = zone
			} else {
				currentFavorite = zone
			}

			return true
		}

		return false // current was not altered
	}

	override func push(_ zone: Zone?  = gHere) {
		if  let target            = zone {
			let bookmarks         = favoritesTargeting(target)
			if  let existing      = bookmarks?.firstUndeleted,
				maybeSetCurrentWithinHere(existing) {

				return
			}

			if  let here          = hereZoneMaybe {
				var bookmark      = ZBookmarks.newBookmark(targeting: target)
				let index         = current?.nextSiblingIndex
				here.addChildNoDuplicate(bookmark, at: index)
				gBookmarks.addToReverseLookup(bookmark)
				setCurrent(bookmark)

				if  !here.isInRecentsGroup,
					let b         = bookmarks?.intersection(recentsGroupZone.children) {
					if  b.count  == 0 {
						let index = currentRecent?.nextSiblingIndex
						bookmark  = ZBookmarks.newBookmark(targeting: target)

						recentsGroupZone.addChildNoDuplicate(bookmark, at: index)
						gBookmarks.addToReverseLookup(bookmark)
					}
				}
			}
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

		return ZBookmarks.newOrExistingBookmark(targeting: zone, addTo: addToRecents ? recentsGroupZone : nil)
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
		let bookmarks = allProgeny.intersection(zone.bookmarksTargetingSelf)
		if  bookmarks.count > 0,
			let parent = bookmarks[0].parentZone {
			setHere(to: parent)
		}
	}

	func showRoot() { setHere(to: rootZone) }

	// MARK: - update
	// MARK: -
    
    func updateFavoritesAndRedraw(needsRedraw: Bool = true, _ onCompletion: Closure? = nil) {
        if  updateAllFavorites() || needsRedraw {
            gRelayoutMaps { onCompletion?() }
        } else {
			gFavoritesMapController?.replaceAllToolTips(gModifierFlags)
            onCompletion?()
        }
    }

    @discardableResult func updateAllFavorites() -> Bool {
		var result = false

		// /////////////////////////////////////////////
		// assure at least one root favorite per db   //
		// call every time favorites MIGHT be altered //
		// /////////////////////////////////////////////

		if  let      bookmarks = rootZone?.allBookmarkProgeny {
			let     rootsGroup = rootsGroupZone
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
				if  let            link  = bookmark.zoneLink {     // always true: allBookmarkProgeny have a zone link
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
							  let        p = bookmark.parentZone, p == rootsGroup {
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

					rootsGroup.addChildAndUpdateOrder(bookmark)
				}
			}

			func createRootsBookmark(named: String) {
				let      bookmark = Zone.uniqueZone(recordName: named + kFavoritesSuffix, in: .mineID)
				bookmark.zoneLink = kColonSeparator + kColonSeparator + named                           // convert into a bookmark
				bookmark.zoneName = named

				rootsGroup.addChildAndUpdateOrder(bookmark)
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

			for zone in rootsGroup.children {
				zone.directAccess = .eReadOnly
			}

			result = missingLost || missingTrash || (missingDestroy && gAddDestroy)
		}

		return result
	}

}
