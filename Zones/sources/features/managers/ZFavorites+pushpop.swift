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

	@discardableResult func push(_ zone: Zone? = gHere) -> Zone? {
		if  let   target = zone {
			let existing = recentsTargeting(target)           // those bookmarks of target already in recents
			let  recents = getRecentsGroup()
			let    index = recentsCurrent?.siblingIndex?.next(forward: false, max: recents.count)
			var bookmark = existing?.firstUndeleted
			if  let from = bookmark?.siblingIndex,
				let   to = index {
				recents.moveChildIndex(from: from, to: to)
			} else {
				bookmark = ZBookmarks.newBookmark(targeting: target)

				recents.addChildNoDuplicate(bookmark, at: index)
			}

			gBookmarks.addToReverseLookup(bookmark)
			setFavoriteCurrents(bookmark)
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
		if  let           c = recentsCurrent ?? otherCurrent,
			let       index = c.siblingIndex,
			let    children = c.siblings,
			let        next = children.next(from: index, forward: gListsGrowDown),
			pop(c) {
			setFavoriteCurrents(next)

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

	func setFavoriteCurrents(_ zone: Zone?, mustBeRecents: Bool = false) {
		guard    let z = zone else { return }
		recentsCurrent = z

		if !mustBeRecents, !currentHere.isInRecentsGroup, !z.isInRecentsGroup {
			otherCurrent = z
		}
	}

	func setAsCurrent(_ zone: Zone?, alterBigMapFocus: Bool = false, makeVisible: Bool = false) {
		if  let target = zone?.bookmarkTarget {
			push(target)

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
			parent.moveChildIndex(from: from, to: to)
		}
	}

	// MARK: - next
	// MARK: -

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

	func insertAsNext(_ zone: Zone) {
		if  let           r = rootZone {
			let      cIndex = r.children.firstIndex(of: zone) ?? 0
			let       index = cIndex.next(forward: gListsGrowDown, max: r.count - 1)

			r.addChildNoDuplicate(zone, at: index)
			setFavoriteCurrents(zone)
		}
	}

	func nextBookmark(down: Bool, amongNotes: Bool = false, moveCurrent: Bool = false, withinRecents: Bool = true) {
		var current   = current(mustBeRecents: withinRecents)
		if  current  == nil {
			current   = push()
		}
		if  let  root = withinRecents ? getRecentsGroup() : amongNotes ? rootZone : hereZoneMaybe {
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
							moveOtherCurrentTo(newCurrent)
						} else {
							setAsCurrent (newCurrent, alterBigMapFocus: !amongNotes, makeVisible: false)
						}
					}
				}
			}
		}
	}

}
