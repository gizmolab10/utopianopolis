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

	func setup(_ onCompletion: IntClosure?) {
		FOREGROUND { [self] in               // avoid error? mutating core data while enumerating
			rootZone = rootZone ?? Zone.uniqueZone(recordName: kFavoritesRootName, in: .mineID)

			if  gCDMigrationState == .firstTime {
				updateAllFavorites() // setup roots group

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

		return bookmarkToMove(is: gSelecting.currentMoveableMaybe) ?? bookmarkToMove(is: currentBookmark)
	}

	func nextList(down: Bool, moveCurrent: Bool = false) {
		if  var   here = hereZoneMaybe,
			let parent = here.parentZone,
			let  index = here.siblingIndex?.next(forward: down, max: parent.count - 1) {
			here       = parent.children[index]

			if  let b = bookmarkToMove, moveCurrent {
				b.moveZone(to: here)
			}

			setHere(to: here)
			gSignal([.sDetails])
		}
	}

	override func push(_ zone: Zone? = gHere) {
		if  let pushMe = zone,
			!gFocusing.findAndSetHere(asParentOf: pushMe) {
			matchOrCreateBookmark(for: pushMe, autoAdd: true)
		}
	}

	@discardableResult func refocus(_ atArrival: @escaping Closure) -> Bool {
		if  let    current = currentBookmark {
			return current.focusThrough(atArrival)
		}

		return false
	}

	// MARK: - update
	// MARK: -

    func updateCurrentFavorite(_ currentZone: Zone? = nil) {
        if  let         zone = currentZone ?? gHereMaybe,
			let     bookmark = whichBookmarkTargets(zone, orSpawnsIt: true),
            let       target = bookmark.bookmarkTarget,
			(gHere == target || !(currentBookmark?.bookmarkTarget?.spawnedBy(gHere) ?? false)) {
//			!gIsRecentlyMode {
            currentBookmark = bookmark
        }
    }
    
    func updateFavoritesAndRedraw(needsRedraw: Bool = true, _ onCompletion: Closure? = nil) {
        if  updateAllFavorites() || needsRedraw {
            gRelayoutMaps { onCompletion?() }
        } else {
            onCompletion?()
        }
    }

    @discardableResult func updateAllFavorites() -> Bool {
		var result = false

		// /////////////////////////////////////////////
		// assure at least one root favorite per db   //
		// call every time favorites MIGHT be altered //
		// /////////////////////////////////////////////

		if  let        bookmarks = rootZone?.allBookmarkProgeny {
			let       rootsGroup = rootsGroupZone
			var   hasDatabaseIDs = [ZDatabaseID] ()
			var         discards = IndexPath()
			var      testedSoFar = ZoneArray ()
			var   missingDestroy = true
			var     missingTrash = true
			var      missingLost = true

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
					} else if let     dbID = bookmark.linkDatabaseID, bookmark.linkIsRoot {
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

					rootsGroup.addChildAndReorder(bookmark)
				}
			}

			func createRootsBookmark(named: String) {
				let      bookmark = Zone.uniqueZone(recordName: named + kFavoritesSuffix, in: .mineID)
				bookmark.zoneLink = kColonSeparator + kColonSeparator + named                           // convert into a bookmark
				bookmark.zoneName = named

				rootsGroup.addChildAndReorder(bookmark)
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

    // MARK: - toggle
    // MARK: -

    func delete(_ favorite: Zone) {
        favorite.moveZone(to: favorite.trashZone)
        gBookmarks.forget(favorite)
        updateAllFavorites()
    }

}
