//
//  ZNext.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/28/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

extension Int {

	func next(increasing: Bool, max: Int) -> Int? {
		if  max <= 0                  { return nil }
		if self <= 0   && !increasing { return max }
		if self >= max &&  increasing { return 0 }

		let    next = self + (increasing ? 1 : -1)
		if     next < 0 || next > max { return nil }
		return next
	}

}

extension Array {

	func next(increasing: Bool, from: Int) -> Element? {
		if  let index = from.next(increasing: increasing, max: count - 1) {
			return self[index]
		}

		return nil
	}

}

extension ZoneArray {

	func nextBookmarkIndex(increasing: Bool, from: Int) -> Int? {
		var next = from
		repeat {
			if  let n = next.next(increasing: increasing, max: count - 1) {
				next  = n
			} else {
				break
			}
		} while !self[next].isBookmark

		return next
	}

	func nextBookmark(increasing: Bool, from: Int) -> Zone? {
		if  let next = nextBookmarkIndex(increasing: increasing, from: from) {
			return self[next]
		}

		return nil
	}

}

extension ZMapEditor {

	func nextBookmark(down: Bool, flags: ZEventFlags) {
		if !flags.exactlySplayed ||
			!gSelecting.currentMoveable.cycleToNextInGroup(down) {
			gFavorites.nextBookmark(down: down, flags: flags)
			gRelayoutMaps()
		}
	}

}

extension ZEssayView {

	func nextNotemark(down: Bool) {
		save()
		clearResizing()
		gFavorites.nextBookmark(down: down, amongNotes: true)
	}

}

extension ZFavorites {

	@discardableResult func showNextList(down: Bool, moveCurrent: Bool = false) -> Zone? {
		if  let here  = nextList(down: down) {
			if  let b = bookmarkToMove, moveCurrent {
				b.moveZone(to: here)
			}

			setHere(to: here)
			gSignal([.spCrumbs, .spSmallMap])

			return here
		}

		return nil
	}

	func insertAsNext(_ zone: Zone) {
		if  let      r = rootZone {
			let cIndex = r.children.firstIndex(of: zone) ?? 0
			let  index = cIndex.next(increasing: !gListsGrowDown, max: r.count - 1)

			r.addChildNoDuplicate(zone, at: index)
			setCurrentFavoriteBoomkarks(to: zone)
		}
	}

	func nextList(down: Bool) -> Zone? {
		if  let  here = hereZoneMaybe,
			let zones = allGroups {
			let index = zones.firstIndex(of: here) ?? 0
			if  let n = index.next(increasing: !down, max: zones.count - 1) {
				return zones[n]
			}
		}

		return rootZone
	}

	func nextListAttributed(down: Bool) -> NSAttributedString {
		let string = nextList(down: down)?.unwrappedName.capitalized ?? kEmpty

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
							var next      = index.next(increasing: !down, max: maxIndex) {
							while !zones[next].isBookmark {
								if  let m = next .next(increasing: !down, max: maxIndex) {
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
							push(newCurrent.bookmarkTarget, down: down)
							setAsCurrent(newCurrent, alterBigMapFocus: !amongNotes)
						}
					}
				}
			}
		}
	}

}
