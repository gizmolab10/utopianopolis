//
//  ZSmallMapRecords.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/22/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

// working zones depends on if we are in essay editing mode

class ZSmallMapRecords: ZRecords {

	var      currentBookmark : Zone?
	var currentBookmarkIndex : Int? {
		for (index, zone) in working.enumerated() {
			if  zone == currentBookmark {
				return index
			}
		}

		return nil
	}

	var working          : ZoneArray { return  gIsEssayMode ? workingNotemarks : workingBookmarks }
	var workingBookmarks : ZoneArray { return (gBrowsingIsConfined ? hereZoneMaybe?.bookmarks : rootZone?.allBookmarkProgeny) ?? [] }
	var workingNotemarks : ZoneArray { return (gBrowsingIsConfined ? hereZoneMaybe?.notemarks : rootZone?.allNotemarkProgeny) ?? [] }

	// MARK:- cycle
	// MARK:-

	func go(down: Bool, amongNotes: Bool = false, moveCurrent: Bool = false, atArrival: Closure? = nil) {
		if  currentBookmark == nil {
			if  self != gRecents {
				gSwapSmallMapMode()
			}

			gRecents.push()
		}

		let   maxIndex = working.count - 1
		var    toIndex = down ? 0 : maxIndex
		if  let target = currentBookmark?.bookmarkTarget {
			for (index, bookmark) in working.enumerated() {
				if  bookmark.bookmarkTarget == target {
					if         down, index < maxIndex {
						toIndex = index + 1         // go down
					} else if !down, index > 0 {
						toIndex = index - 1         // go up
					}

					break
				}
			}

			if  toIndex.within(0 ... maxIndex) {
				let newCurrent = working[toIndex]

				if  moveCurrent {
					moveCurrentTo(newCurrent)
				} else {
					setAsCurrent(newCurrent, alterHere: true)
				}
			}
		}

		atArrival?()
	}

	func moveCurrentTo(_ iZone: Zone) {
		if  let parent = iZone.parentZone,
			parent    == currentBookmark?.parentZone,
			let   from = currentBookmark?.siblingIndex,
			let     to = iZone.siblingIndex {
			parent.moveChildIndex(from: from, to: to)
		}
	}

	func setAsCurrent(_  iZone: Zone?, alterHere: Bool = false) {
		if  alterHere,
			makeVisibleAndMarkInSmallMap(iZone) {
			iZone?.grab()
		}

		if  let       tHere = iZone?.bookmarkTarget {
			currentBookmark = iZone

			if  alterHere {
				if  let    dbID = tHere.databaseID {
					gDatabaseID = dbID        // so gRecords below will be correct
				}

				gRecords?.currentHere = tHere // avoid push

				gHere.grab()
			}

			if  gIsMapMode {
				focusOnGrab(.eSelected, shouldGrab: true) {
					gSignal([.sRelayout])
				}
			} else if gCurrentEssayZone != tHere {
				gEssayView?.resetCurrentEssay(tHere.note)
			}
		}
	}

	func nextWorkingIndex(after index: Int, going down: Bool) -> Int {
		let  increment = (down ? 1 : -1)
		var       next = index + increment
		let      count = working.count
		if  next      >= count {
			next       = 0
		} else if next < 0 {
			next       = count - 1
		}

		return next
	}

	func targeting(_ target: Zone, in array: ZoneArray?, orSpawnsIt: Bool = true) -> Zone? {
		return array?.whoseTargetIntersects(with: [target], orSpawnsIt: orSpawnsIt)
	}

	func workingBookmark(for target: Zone) -> Zone? {
		return targeting(target, in: workingBookmarks, orSpawnsIt: false)
	}

	func whichBookmarkTargets(_ target: Zone, orSpawnsIt: Bool) -> Zone? {
		if  target.databaseID != nil {
			return targeting(target, in: rootZone?.allBookmarkProgeny, orSpawnsIt: orSpawnsIt)
		}

		return nil
	}

	func bookmarkTargeting(_ target: Zone) -> Zone? {
		return whichBookmarkTargets(target, orSpawnsIt: false)
	}

	// MARK:- pop and push
	// MARK:-

	func push(_ zone: Zone? = gHere, intoNotes: Bool = false) {}

	@discardableResult func pop(_ zone: Zone? = gHereMaybe) -> Bool {
		if  let   target = zone,
			let bookmark = workingBookmark(for: target) {
			go(down: true) {
				bookmark.deleteSelf(permanently: true) {}
			}

			return true
		}

		return false
	}

	@discardableResult func popAndUpdate() -> Zone? {
		if  pop(),
			workingBookmarks.count > 0 {
			currentBookmark = workingBookmarks[0]
		}

		return currentBookmark
	}

	func findAndSetHereAsParentOfBookmarkTargeting(_ target: Zone) -> Bool {
		if  let  bookmark = bookmarkTargeting(target),
			let    parent = bookmark.parentZone {
			hereZoneMaybe = parent

			return true
		}

		return false
	}

	func insertAsNext(_ zone: Zone) {
		currentBookmark = zone
		let      cIndex = currentBookmarkIndex ?? 0
		let       index = nextWorkingIndex(after: cIndex, going: gListsGrowDown)

		rootZone?.addChildSafely(zone, at: index)
	}

	func removeBookmark(for zone: Zone? = gHereMaybe) {
		if  let   target = zone,
			let bookmark = workingBookmark(for: target) {
			bookmark.deleteSelf(permanently: true) {}
		}
	}

	// MARK:- focus
	// MARK:-

	func revealBookmark(of target: Zone) {

		// locate and make bookmark of target visible and mark it

		if  let b = whichBookmarkTargets(target, orSpawnsIt: false) {
			makeVisibleAndMarkInSmallMap(b)
		}
	}

	@discardableResult func makeVisibleAndMarkInSmallMap(_  iZone: Zone? = nil) -> Bool {
		if  let zone     = iZone,
			let parent   = zone.parentZone,
			currentHere != parent {
			currentHere.collapse()

			currentHere = parent

			currentHere.expand()

			return true
		}

		return false
	}

	@discardableResult func updateCurrentForMode() -> Zone? {
		return gIsRecentlyMode ? updateCurrentRecent() : updateCurrentBookmark()
	}

	@discardableResult func updateCurrentBookmark() -> Zone? {
		if  let        here = gHereMaybe,
			let    bookmark = whichBookmarkTargets(here, orSpawnsIt: false),
			bookmark.isInSmallMap,
			!(bookmark.bookmarkTarget?.spawnedBy(here) ?? false) {
			currentBookmark = bookmark

			return currentBookmark
		}

		return nil
	}

	@discardableResult func updateCurrentRecent() -> Zone? {
		if  let recents   = rootZone?.allBookmarkProgeny, recents.count > 0 {
			var targets   = ZoneArray()

			if  var grab  = gSelecting.firstGrab {
				if  let b = grab.bookmarkTarget {
					grab  = b
				}

				targets.append(grab)
			}

			if  let here  = gHereMaybe {
				targets.appendUnique(item: here)
			}

			if  let bookmark    = recents.whoseTargetIntersects(with: targets, orSpawnsIt: false) {
				currentBookmark = bookmark

				if  let  parent = bookmark.parentZone,
					let   index = bookmark.siblingIndex, index != 0 {
					parent.moveChildIndex(from: index, to: 0)
				}

				return bookmark
			}
		} else {
			currentBookmark     = nil // no recents, therefor no current bookmark
		}

		return nil
	}

	func grab(_ zone: Zone) {
		zone.grab()

		if  let p = zone.parentZone {
			if  let h = hereZoneMaybe, h != p {
				hereZoneMaybe = p

				h.collapse()
			}

			p.expand()
		}
	}

	@discardableResult func swapBetweenBookmarkAndTarget(doNotGrab: Bool = true) -> Bool {
		if  let cb = currentBookmark,
			cb.isGrabbed {
			cb.bookmarkTarget?.grab() // grab target in big map
		} else if doNotGrab {
			return false
		} else if let bookmark = updateCurrentForMode() {
			grab(bookmark)
		} else {
			let bookmarks = gHere.bookmarksTargetingSelf

			for bookmark in bookmarks {
				if  bookmark.isInSmallMap {
					if  bookmark.root != rootZone {
						gSwapSmallMapMode() // switch to other small map
					}

					gCurrentSmallMapRecords?.grab(bookmark)

					return true
				}
			}

			push()
		}

		return true
	}

	func findAndSetHere(asParentOf zone: Zone) -> Bool {
		var found = gRecents   .findAndSetHereAsParentOfBookmarkTargeting(zone)
		found     = gFavorites .findAndSetHereAsParentOfBookmarkTargeting(zone) || found

		return found
	}

	@discardableResult func addNewBookmark(for iZone: Zone?, action: ZBookmarkAction) -> Zone? {

		// ////////////////////////////////////////////
		// 1. zone  is a bookmark, pass a deep copy  //
		// 2. zone not a bookmark, pass the original //
		// ////////////////////////////////////////////

		if  let       zone = iZone,
			let       root = rootZone {
			let  newParent = currentHere
			var     parent = zone.parentZone
			let isBookmark = zone.isBookmark
			let  actNormal = action == .aBookmark

			if  !actNormal {
				let          basis = isBookmark ? zone.crossLink! : zone

				if  let recordName = basis.ckRecordName {
					parent         = currentHere

					for workingFavorite in root.allBookmarkProgeny {
						if  workingFavorite.isInEitherMap,
							databaseID     == workingFavorite.bookmarkTarget?.databaseID,
							recordName     == workingFavorite.linkRecordName {
							currentBookmark = workingFavorite

							return workingFavorite
						}
					}
				}
			}

			if  let           count = parent?.count {
				var bookmark: Zone? = isBookmark ? zone.deepCopy(dbID: nil) : nil               // cases 1 and 2
				var           index = parent?.children.firstIndex(of: zone) ?? count

				if  action         == .aCreateBookmark,
					let      fIndex = currentBookmarkIndex {
					index           = nextWorkingIndex(after: fIndex, going: gListsGrowDown)
				}

				bookmark            = gBookmarks.create(withBookmark: bookmark, action, parent: newParent, atIndex: index, zone.zoneName)

				bookmark?.maybeNeedSave()

				if  actNormal {
					parent?.updateCKRecordProperties()
					parent?.maybeNeedMerge()
				}

				if !isBookmark {
					bookmark?.crossLink = zone

					gBookmarks.addToReverseLookup(bookmark!)
				}

				return bookmark!
			}
		}

		return nil
	}

}
