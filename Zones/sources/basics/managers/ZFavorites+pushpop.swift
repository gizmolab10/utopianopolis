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
	func recentsTargeting(_ target: Zone) -> Zone? { return getRecentsGroup().children.whoseTargetIntersects(with: [target]).firstUndeleted }

	@discardableResult func push(_ iZone: Zone? = gHere, down: Bool = true) -> Zone? {
		if  let zone          = iZone {
			let recents       = getRecentsGroup()
			let prior         = recentCurrent?.siblingIndex ?? 0
			var bookmark      = zone.isValidBookmark ? zone : recentsTargeting(zone)             // bookmark pointing to zone is already present
			if  let to        = !down ? prior : recents.children.nextBookmarkIndex(increasing: true,  from: prior) {
				if  let from  = bookmark?.siblingIndex,
					let guess =                 recents.children.nextBookmarkIndex(increasing: false, from: from) {

					if ![from, prior, guess].contains(to) {
						recents.moveChild(from: from, to: to)
					}
				} else {
					bookmark  = ZBookmarks.newBookmark(targeting: zone)

					recents.addChildNoDuplicate(bookmark, at: to)
				}
			}

			if  gBookmarks.addToReverseLookup(bookmark) {
				gRelationships.addBookmarkRelationship(bookmark, target: zone, in: bookmark!.databaseID)
			}

			FOREGROUND(after: 0.01) { [self] in
				setCurrentFavoriteBookmark(to: bookmark)
				resetRecents()
				gDispatchSignals([.spFavoritesMap])
			}

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
			setCurrentFavoriteBookmark(to: next)

			if  let    here = next.bookmarkTarget {
				gHere       = here

				gHere.grab()
			}
		}

		gDispatchSignals([.sDetails, .spCrumbs, .spRelayout])
	}

	func popNoteAndUpdate() -> Bool {
		if  pop(),
			let  notemark = rootZone?.notemarks.first,
			let    target = notemark.bookmarkTarget,
			let      note = target.note {
			gCurrentEssay = note

			push(target)
			setAsCurrent(notemark)
			gDispatchSignals([.spFavoritesMap, .spCrumbs])

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

	func setCurrentFavoriteBookmark(to iBookmark: Zone?) {
		if  let bookmarks = iBookmark?.bookmarkTarget?.bookmarksTargetingSelf {
			for bookmark in bookmarks {
				if  bookmark.isInFavorites {
					if  bookmark.isInRecentsGroup {
						recentCurrent = bookmark
					} else if !currentHere.isInRecentsGroup {
						otherCurrent  = bookmark
					}
				}
			}
		}
	}

	func setAsCurrent(_ bookmark: Zone?, alterMainMapFocus: Bool = false) {
		if  let target = bookmark?.bookmarkTarget {
			if  alterMainMapFocus {
				gDatabaseID          = target.databaseID
				gRecords.currentHere = target // avoid push
				recentCurrent        = bookmark

				target.grab()
			}

			if  gIsMapMode {
				gFocusing.focusOnGrab(.eSelected) {
					gDispatchSignals([.spCrumbs, .spRelayout, .spDataDetails])
				}
			} else if gCurrentEssayZone != target {
				gEssayView?.resetCurrentEssay(target.note)
				gDispatchSignals([.spCrumbs, .sDetails, .spFavoritesMap])
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
