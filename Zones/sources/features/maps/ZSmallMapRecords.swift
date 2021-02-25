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

	var working          : ZoneArray { return  gIsNoteMode ? workingNotemarks : workingBookmarks }
	var workingBookmarks : ZoneArray { return (gBrowsingIsConfined ? hereZoneMaybe?.bookmarks : rootZone?.allBookmarkProgeny) ?? [] }
	var workingNotemarks : ZoneArray { return (gBrowsingIsConfined ? hereZoneMaybe?.notemarks : rootZone?.allNotemarkProgeny) ?? [] }

	// MARK:- switch
	// MARK:-

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

	@discardableResult func pop(_ iZone: Zone? = gHereMaybe) -> Bool {
		if  let name = iZone?.ckRecordName {
			for bookmark in workingBookmarks {
				if  name == bookmark.bookmarkTarget?.ckRecordName {
					go(down: gListsGrowDown) {
						bookmark.deleteSelf(permanently: true) {}
					}

					return true

				}
			}
		}

		return false
	}

	@discardableResult func popAndUpdate() -> Zone? {
		if  !pop(),
			workingBookmarks.count > 0 {
			currentBookmark = workingBookmarks[0]
		}

		return currentBookmark
	}

	func go(down: Bool, amongNotes: Bool = false, atArrival: Closure? = nil) {
		if  currentBookmark == nil {
			gRecents.push()
		}

		let    max = working.count - 1
		var fIndex = down ? 0 : max

		if  fIndex >= 0,
			let target = currentBookmark?.bookmarkTarget {
			for (iIndex, bookmark) in working.enumerated() {
				if  bookmark.bookmarkTarget == target {
					if         down, iIndex < max {
						fIndex = iIndex + 1         // go down
					} else if !down, iIndex > 0 {
						fIndex = iIndex - 1         // go up
					}

					break
				}
			}

			if  working.count > fIndex {
				setAsCurrent(working[fIndex], alterHere: true)
			}
		}

		atArrival?()
	}

	func revealBookmark(of target: Zone) {

		// locate and make bookmark of target visible and mark it

		if  let b = whichBookmarkTargets(target) {
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

	// MARK:- focus
	// MARK:-

	func setAsCurrent(_  iZone: Zone?, alterHere: Bool = false) {
		if  alterHere,
			makeVisibleAndMarkInSmallMap(iZone) {
			iZone?.grab()
		}

		if  let       tHere = iZone?.bookmarkTarget {
			gHere           = tHere
			currentBookmark = iZone

			gHere.grab()

			maybeRefocus(.eSelected) {
				gSignal([.sRelayout])
			}
		}
	}

	func whichBookmarkTargets(_ iTarget: Zone?, orSpawnsIt: Bool = true) -> Zone? {
		if  let target = iTarget, target.databaseID != nil {
			return rootZone?.allBookmarkProgeny.whoseTargetIntersects(with: [target], orSpawnsIt: orSpawnsIt)
		}

		return nil
	}

	@discardableResult func updateCurrentForMode() -> Zone? {
		return gIsRecentlyMode ? updateCurrentRecent() : updateCurrentBookmark()
	}

	@discardableResult func updateCurrentBookmark() -> Zone? {
		if  let    bookmark = whichBookmarkTargets(gHereMaybe, orSpawnsIt: false),
			bookmark.isInSmallMap,
			!(bookmark.bookmarkTarget?.spawnedBy(gHere) ?? false) {
			currentBookmark = bookmark

			return currentBookmark
		}

		return nil
	}

	@discardableResult func updateCurrentRecent() -> Zone? {
		if  let recents  = rootZone?.allBookmarkProgeny, recents.count > 0 {
			var targets  = ZoneArray()

			if  let grab = gSelecting.firstGrab {
				targets.append(grab)
			}

			if  let here = gHereMaybe {
				targets.appendUnique(contentsOf: [here])
			}

			if  targets.count   > 0,
				let bookmark    = recents.whoseTargetIntersects(with: targets) {
				currentBookmark = bookmark

				return bookmark
			}
		} else {
			currentBookmark     = nil // no recents, therefor no current bookmark
		}

		return nil
	}

	@discardableResult func swapBetweenBookmarkAndTarget(doNotGrab: Bool = true) -> Bool {
		if  let cb = currentBookmark,
			cb.isGrabbed {
			cb.bookmarkTarget?.grab() // grab target in big map
		} else if doNotGrab {
			return false
		} else if let bookmark = updateCurrentForMode() {
			bookmark.grab()

			if  let h = hereZoneMaybe,
				let p = bookmark.parentZone,
				p.isInSmallMap,
				p != h {
				h.collapse()
				p.expand()

				hereZoneMaybe = p
			}
		} else {
			push()
		}

		return true
	}

	func push(intoNotes: Bool = false) {}

	@discardableResult func createBookmark(for iZone: Zone?, action: ZBookmarkAction) -> Zone? {

		// ////////////////////////////////////////////
		// 1. zone not a bookmark, pass the original //
		// 2. zone is a bookmark, pass a deep copy   //
		// ////////////////////////////////////////////

		if  let       zone = iZone,
			let       root = rootZone {
			let  newParent = currentHere
			let databaseID = zone.databaseID
			var     parent = zone.parentZone
			let isBookmark = zone.isBookmark
			let  actNormal = action == .aBookmark

			if  !actNormal {
				let          basis = isBookmark ? zone.crossLink! : zone

				if  let recordName = basis.ckRecordName {
					parent         = currentHere

					for workingFavorite in root.allBookmarkProgeny {
						if  !workingFavorite.isInTrash,
							databaseID     == workingFavorite.bookmarkTarget?.databaseID,
							recordName     == workingFavorite.linkRecordName {
							currentBookmark = workingFavorite

							return workingFavorite
						}
					}
				}
			}

			if  let           count = parent?.count {
				var bookmark: Zone? = isBookmark ? zone.deepCopy : nil               // 1. and 2.
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

					gBookmarks.persistForLookupByTarget(bookmark!)
				}

				return bookmark!
			}
		}

		return nil
	}

}
