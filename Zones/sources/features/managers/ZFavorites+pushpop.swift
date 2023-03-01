//
//  ZFavorites+pushpop.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/26/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

extension ZFavorites {

	// MARK: - pop and push
	// MARK: -

	func resetRecents() { recentsMaybe = nil } // gotta re-construct recents group

	@discardableResult func push(_ zone: Zone? = gHere, down: Bool = true) -> Zone? {
		if  let target    = zone {
			let prior     = recentsCurrent?.siblingIndex ?? 0
			let recents   = getRecentsGroup()
			var bookmark  = recentsTargeting(target)?.firstUndeleted           // bookmark pointing to target already is in recents
			if  let from  = bookmark?.siblingIndex,
				let to    = !down ? prior : recents.children.nextBookmarkIndex(increasing: true,  from: prior),
				let guess =                 recents.children.nextBookmarkIndex(increasing: false, from: from) {
				if ![from, prior, guess].contains(to) {
					recents.moveChild(from: from, to: to)
				}
			} else {
				bookmark = ZBookmarks.newBookmark(targeting: target)

				recents.addChildNoDuplicate(bookmark, at: prior)
			}

			gBookmarks.addToReverseLookup(bookmark)
			setCurrentFavoriteBoomkarks(to: bookmark)
			resetRecents()
			gSignal([.spSmallMap])

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
		if  let           c = recentsCurrent ?? otherCurrent,
			let       index = c.siblingIndex,
			let    children = c.siblings,
			let        next = children.next(increasing: !gListsGrowDown, from: index),
			pop(c) {
			setCurrentFavoriteBoomkarks(to: next)

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
			let    target = notemark.bookmarkTarget,
			let      note = target.note {
			gCurrentEssay = note

			push(target)
			setAsCurrent(notemark, makeVisible: true)
			gSignal([.spSmallMap, .spCrumbs])

			return true
		}

		return false
	}

	// MARK: - current
	// MARK: -

	var current : Zone? {
		if  let here  = hereZoneMaybe {
			if  here == getRecentsGroup() {
				return recentsCurrent
			}

			return otherCurrent
		}

		return nil
	}

	func current(mustBeRecents: Bool = false) -> Zone? {
		let    useRecents = mustBeRecents || currentHere.isInRecentsGroup
		return useRecents ? recentsCurrent : otherCurrent
	}

	func isCurrent(_ zone: Zone) -> Bool {
		return [recentsCurrent, otherCurrent].contains(zone)
	}

	func setCurrentFavoriteBoomkarks(to zone: Zone?, mustBeRecents: Bool = false) {
		if      let          z = zone {
			if  let          t = z.bookmarkTarget,
				let          r = recentsTargeting(t)?.firstUndeleted {
				recentsCurrent = r
			}

			if !mustBeRecents, !currentHere.isInRecentsGroup, !z.isInRecentsGroup {
				otherCurrent   = z
			}
		}
	}

	func setAsCurrent(_ zone: Zone?, alterBigMapFocus: Bool = false, makeVisible: Bool = false) {
		if  let target = zone?.bookmarkTarget {
			if  alterBigMapFocus {
				gDatabaseID          = target.databaseID
				gRecords.currentHere = target // avoid push

				target.grab()
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

	func moveOtherCurrentTo(_ zone: Zone) {
		if  let parent = zone.parentZone,
			let      p = otherCurrent?.parentZone, p == parent,
			let   from = otherCurrent?.siblingIndex,
			let     to = zone.siblingIndex {
			parent.moveChild(from: from, to: to)
		}
	}

}
