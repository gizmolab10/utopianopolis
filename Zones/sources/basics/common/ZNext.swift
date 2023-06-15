//
//  ZNext.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/28/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

extension Int {

	func next(goingDown: Bool, max: Int) -> Int? {
		if  max <= 0                  { return nil }
		if self <= 0   &&  !goingDown { return max }
		if self >= max &&   goingDown { return 0 }

		let    next = self + (goingDown ? 1 : -1)
		if     next < 0 || next > max { return nil }
		return next
	}

}

extension Array {

	func next(goingDown: Bool, from: Int) -> Element? {
		if  let index = from.next(goingDown: goingDown, max: count - 1) {
			return self[index]
		}

		return nil
	}

}

extension ZoneArray {

	func indexOfNextUngrabbed(up: Bool) -> Int {
		let   array = up ? self : reversed()
		let     max = count - 1
		var highest = max

		if  count > 1 {
			for (index, zone) in array.enumerated() {
				if !zone.isGrabbed {
					highest = index
				} else {
					break
				}
			}
		}

		if !up {
			highest = max - highest
		}

		return highest
	}

	func nextBookmarkIndex(increasing: Bool, from: Int) -> Int? {
		var remaining = count
		var      next = from
		repeat {
			if  let      n = next.next(goingDown: increasing, max: count - 1) {
				remaining -= 1
				next       = n
			} else {
				break
			}
		} while  remaining > 0 && !self[next].isBookmark

		return next
	}

	func nextBookmark(increasing: Bool, from: Int) -> Zone? {
		if  let next = nextBookmarkIndex(increasing: increasing, from: from) {
			return self[next]
		}

		return nil
	}

	func firstIndexWithRecordNameMatching(_ other: Zone) -> Int? {
		if  let name = other.recordName {
			for (index, zone) in enumerated() {
				if  zone.recordName == name {
					return index
				}
			}
		}

		return nil
	}

}

extension ZMapEditor {

	func nextBookmark(down: Bool, flags: ZEventFlags) {
		if !flags.exactlySplayed ||
			!gSelecting.currentMoveable.cycleToNextInGroup(down) {
			gFavoritesCloud.nextBookmark(down: down, flags: flags)
			gRelayoutMaps()
		}
	}

}

extension ZEssayView {

	func nextNotemark(down: Bool) {
		writeViewToTraits()
		clearImageResizing()
		gFavoritesCloud.nextBookmark(down: down, amongNotes: true)
	}

}

extension ZFavorites {

	@discardableResult func showNextList(down: Bool, moveCurrent: Bool = false, travel: Bool = true) -> Zone? {
		if  let here  = nextList(down: down) {
			if  let b = bookmarkToMove, moveCurrent {
				b.moveZone(to: here)
			}

			if  travel {
				setHere(to: here)
			}
			
			gDispatchSignals([.spCrumbs, .spFavoritesMap])

			return here
		}

		return nil
	}

	func insertAsNext(_ zone: Zone) {
		if  let      r = rootZone {
			let cIndex = r.children.firstIndex(of: zone) ?? 0
			let  index = cIndex.next(goingDown: !gListsGrowDown, max: r.count - 1)

			r.addChildNoDuplicate(zone, at: index)
			setCurrentFavoriteBookmark(to: zone)
		}
	}

	func nextList(down: Bool) -> Zone? {
		if  let  here = hereZoneMaybe,
			let zones = rootZone?.allGroups,
			let index = zones.firstIndexWithRecordNameMatching(here),
			let  next = index.next(goingDown: !down, max: zones.count - 1) {
			return zones[next]
		}

		return rootZone
	}

	func nextListAttributedTitle(forward: Bool) -> NSAttributedString {
		let string = nextList(down: forward)?.unwrappedName.capitalized ?? kEmpty

		return string.darkAdaptedTitle
	}

	func nextBookmark(down: Bool, flags: ZEventFlags) {
		let COMMAND = flags.hasCommand
		let  OPTION = flags.hasOption
		let   SHIFT = flags.hasShift

		if  COMMAND {
			showNextList(down: down, moveCurrent: OPTION)
		} else {
			nextBookmark(down: down, withinRecents: SHIFT, moveCurrent: OPTION)
		}
	}

	func nextBookmark(down: Bool, amongNotes: Bool = false, withinRecents: Bool = true, moveCurrent: Bool = false) {
		var current   = current(mustBeRecents: withinRecents)
		if  current  == nil {
			current   = push() // so when user comes back, we return to this focus
		}
		if  let  root = withinRecents ? getRecentsGroup() : amongNotes ? rootZone : hereZoneMaybe {
			let zones = amongNotes    ? root.notemarks    : root.bookmarks
			let count = zones.count
			if  count > 1 {           // there is no next for count == 0 or 1
				let    maxIndex = count - (moveCurrent ? 2 : 1)
				var     toIndex = down ? maxIndex : 0
				if  let  target = current?.zoneLink {
					for (index, bookmark) in zones.enumerated() {
						if  target       == bookmark.zoneLink,
							var next      = index.next(goingDown: !down, max: maxIndex) {
							while zones[next].bookmarkTarget == nil {
								if  let m = next .next(goingDown: !down, max: maxIndex) {
									next  = m
								} else {
									break
								}
							}

							toIndex       = next

							break
						}
					}

					if  toIndex.isWithin(0 ... maxIndex) {
						let  newCurrent = zones[toIndex]
						if  moveCurrent {
							moveOtherCurrentTo(newCurrent)
						} else {
							push(newCurrent.bookmarkTarget, down: down) // reposition new current so reversing direction works
							setAsCurrent(newCurrent, alterMainMapFocus: !amongNotes)
						}
					}
				}
			}
		}
	}

}
