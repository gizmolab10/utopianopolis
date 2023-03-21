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

	func resetRecents() { recentsMaybe = nil } // force reconstruction of recents group

	@discardableResult func push(_ zone: Zone? = gHere, down: Bool = true) -> Zone? {
		if  let target        = zone {
			let prior         = recentCurrent?.siblingIndex ?? 0
			let recents       = getRecentsGroup()
			var bookmark      = recents.children.whoseTargetIntersects(with: [target]).firstUndeleted           // bookmark pointing to target is already present
			if  let to        = !down ? prior : recents.children.nextBookmarkIndex(increasing: true,  from: prior) {
				if  let from  = bookmark?.siblingIndex,
					let guess =                 recents.children.nextBookmarkIndex(increasing: false, from: from) {

					if ![from, prior, guess].contains(to) {
						recents.moveChild(from: from, to: to)
					}

					bookmark  = recents[to]
				} else {
					bookmark  = ZBookmarks.newBookmark(targeting: target)

					recents.addChildNoDuplicate(bookmark, at: to)
				}
			}

			gBookmarks.addToReverseLookup(bookmark)
			setCurrentFavoriteBoomkarks(to: bookmark)
			resetRecents()
			gSignal([.spFavoritesMap])

			return bookmark
		}

		return nil
	}

	@discardableResult func pop(_ iZone: Zone? = gHereMaybe) -> Bool {
		var flag             = false
		if  let zone         = iZone,
			zone            != currentlyPopping {  // eliminate recursion
			let priorPopping = currentlyPopping
			currentlyPopping = zone

			if  zone.isInFavorites {
				zone.deleteSelf(permanently: true) { [self] flag in
					if  flag {
						resetRecents()
					}
				}

				flag = true
			} else if let bookmarks = favoritesTargeting(zone) {
				for bookmark in bookmarks {
					bookmark.deleteSelf(permanently: true) { flag in }
				}

				resetRecents()

				flag = true
			}

			currentlyPopping = priorPopping
		}

		return flag
	}

	func popAndUpdateCurrent() {
		if  let           c = recentCurrent ?? otherCurrent,
			let       index = c.siblingIndex,
			let    children = c.siblings,
			let        next = children.nextBookmark(increasing: false, from: index), next != c,
			pop(c) {
			setCurrentFavoriteBoomkarks(to: next)

			if  let    here = next.bookmarkTarget {
				gHere       = here

				gHere.grab()
			}
		}

		gSignal([.sDetails, .spCrumbs, .spRelayout])
	}

	func popNoteAndUpdate() -> Bool {
		if  pop(),
			let  notemark = rootZone?.notemarks.first,
			let    target = notemark.bookmarkTarget,
			let      note = target.note {
			gCurrentEssay = note

			push(target)
			setAsCurrent(notemark)
			gSignal([.spFavoritesMap, .spCrumbs])

			return true
		}

		return false
	}

	// MARK: - current
	// MARK: -

	var current : Zone? {
		if  let here  = hereZoneMaybe {
			if  here == getRecentsGroup() {
				return recentCurrent
			}

			return otherCurrent
		}

		return nil
	}

	func current(mustBeRecents: Bool = false) -> Zone? {
		let    useRecents = mustBeRecents || currentHere.isInRecentsGroup
		return useRecents ? recentCurrent : otherCurrent
	}

	func isCurrent(_ zone: Zone) -> Bool {
		return [recentCurrent, otherCurrent].contains(zone)
	}

	func setCurrentFavoriteBoomkarks(to zone: Zone?, mustBeRecents: Bool = false) {
		if      let          z = zone {
			if  let          t = z.bookmarkTarget,
				let          r = recentsTargeting(t)?.firstUndeleted {
				recentCurrent = r
			}

			if !mustBeRecents, !currentHere.isInRecentsGroup, !z.isInRecentsGroup {
				otherCurrent   = z
			}
		}
	}

	func setAsCurrent(_ zone: Zone?, alterMainMapFocus: Bool = false) {
		if  let target = zone?.bookmarkTarget {
			if  alterMainMapFocus {
				gDatabaseID          = target.databaseID
				gRecords.currentHere = target // avoid push
				recentCurrent        = zone

				target.grab()
			}

			if  gIsMapMode {
				gFocusing.focusOnGrab(.eSelected) {
					gSignal([.spCrumbs, .spRelayout, .spDataDetails])
				}
			} else if gCurrentEssayZone != target {
				gEssayView?.resetCurrentEssay(target.note)
				gSignal([.spCrumbs, .sDetails, .spFavoritesMap])
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
