//
//  ZoneArray.swift
//  iFocus
//
//  Created by Jonathan Sand on 4/22/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

extension ZoneArray {

	init(set: Set<Zone>) {
		self.init()

		for zone in set {
			append(zone)
		}
	}

	var anyInRecently: Bool {
		for     zone in self {
			if  zone.isInRecents {
				return true
			}
		}

		return false
	}

	func updateOrder() { updateOrdering(start: 0.0, end: 1.0) }

	func orderLimits() -> (start: Double, end: Double) {
		var start = 1.0
		var   end = 0.0

		for zone in self {
			let  order = zone.order
			let  after = order > end
			let before = order < start

			if  before {
				start  = order
			}

			if  after {
				end    = order
			}
		}

		return (start, end)
	}

	func sortedByReverseOrdering() -> Array {
		return sorted { (a, b) -> Bool in
			return a.order > b.order
		}
	}

	func updateOrdering(start: Double, end: Double) {
		let increment = (end - start) / Double(self.count + 2)

		for (index, child) in self.enumerated() {
			let newOrder = start + (increment * Double(index + 1))
			let    order = child.order

			if  order      != newOrder {
				child.order = newOrder

				child.maybeNeedSave()
			}
		}

		gSelecting.updateCousinList()
	}

	func traverseAncestors(_ block: ZoneToStatusClosure) {
		for zone in self {
			zone.safeTraverseAncestors(visited: [], block)
		}
	}

	func traverseAllAncestors(_ block: @escaping ZoneClosure) {
		for zone in self {
			zone.safeTraverseAncestors(visited: []) { iZone -> ZTraverseStatus in
				block(iZone)

				return .eContinue
			}
		}
	}

	func rootMost(goingUp: Bool) -> Zone? {
		guard count > 0 else { return nil }

		var      candidate = first

		if count > 1 {
			var candidates = ZoneArray ()
			var      level = candidate?.level ?? 100
			var      order = goingUp ? 1.0 : 0.0

			for zone in self {
				if  level      == zone.level {
					candidates.append(zone)
				} else {
					candidate   = zone
					level       = candidate!.level
					candidates  = [candidate!]
				}
			}

			for zone in candidates {
				let    zOrder = zone.order

				if  goingUp  ? (zOrder < order) : (zOrder > order) {
					order     = zOrder
					candidate = zone
				}
			}
		}

		return candidate
	}

	var rootMost: Zone? {
		var candidate: Zone?

		for zone in self {
			if  candidate == nil || zone.level < candidate!.level {
				candidate = zone
			}
		}

		return candidate
	}

	mutating func duplicate() {
		var duplicates = ZoneArray ()
		var    indices = [Int] ()

		sort { (a, b) -> Bool in
			return a.order < b.order
		}

		for zone in self {
			if  let index = zone.siblingIndex {
				let duplicate = zone.deepCopy

				duplicates.append(duplicate)
				indices.append(index)
			}
		}

		while   var index = indices.last, let duplicate = duplicates.last, let zone = last {
			if  let     p = zone.parentZone {
				index    += (gListsGrowDown ? 1 : 0)

				p.addAndReorderChild(duplicate, at: index)
				duplicate.grab()
			}

			duplicates.removeLast()
			indices   .removeLast()
			removeLast()
		}

		gFavorites.updateFavoritesAndRedraw()
	}

	mutating func reverseOrder() {
		if  count > 1 {
			let  last = count - 1
			let range = 0 ... (last - 1) / 2

			for index in range {
				let   a = self[index]
				let   b = self[last - index]
				let   o = a.order
				a.order = b.order
				b.order = o

				a.maybeNeedSave()
				b.maybeNeedSave()
			}

			gSelecting.hasNewGrab = gSelecting.currentMoveable
		}
	}

	func alphabetize(_ iBackwards: Bool = false) {
		alterOrdering { iZones -> (ZoneArray) in
			return iZones.sorted { (a, b) -> Bool in
				let aName = a.unwrappedName
				let bName = b.unwrappedName

				return iBackwards ? (aName > bName) : (aName < bName)
			}
		}
	}

	func sortByLength(_ iBackwards: Bool = false) {
		let font = gWidgetFont

		alterOrdering { iZones -> (ZoneArray) in
			return iZones.sorted { (a, b) -> Bool in
				let aLength = a.zoneName?.widthForFont(font) ?? 0
				let bLength = b.zoneName?.widthForFont(font) ?? 0

				return iBackwards ? (aLength > bLength) : (aLength < bLength)
			}
		}
	}

	func alterOrdering(_ iBackwards: Bool = false, with sortClosure: ZonesToZonesClosure) {
		if  var parent = commonParent ?? first {
			var  zones = self

			if  count == 1, first != nil {
				parent = first!
				zones  = parent.children
			}

			parent.children.updateOrder()

			if  zones.count > 1 {
				let (start, end) = zones.orderLimits()
				zones            = sortClosure(zones)

				zones.updateOrdering(start: start, end: end)
				parent.respectOrder()
				parent.children.updateOrder()
				gRedrawMaps()
			}

			gSelecting.hasNewGrab = gSelecting.currentMoveable
		}
	}

	var commonParent: Zone? {
		let candidate = first?.parentZone

		if  count == 1 {
			return first
		}

		for zone in self {
			if  let parent = zone.parentZone, parent != candidate {   // not all of the grabbed zones share the same parent
				return nil
			}
		}

		return candidate

	}

	var first: Zone? {
		var grabbed: Zone?

		if  count > 0 {
			grabbed = self[0]
		}

		return grabbed
	}

	var last: Zone? {
		var grabbed: Zone?

		if  count > 0 {
			grabbed = self[count - 1]
		}

		return grabbed
	}

	func assureAdoption() {
		traverseAllAncestors { ancestor in
			ancestor.adopt()
		}
	}

	func grabAppropriate() -> Zone? {
		if  let     grab = gListsGrowDown ? first : last,
			let   parent = grab.parentZone {
			let siblings = parent.children
			var    count = siblings.count
			let      max = count - 1

			if siblings.count == count {
				for zone in self {
					if siblings.contains(zone) {
						count -= 1
					}
				}
			}

			if  var           index  = grab.siblingIndex, max > 0, count > 0 {
				if !grab.isGrabbed {
					if        index == max &&   gListsGrowDown {
						index        = 0
					} else if index == 0   &&  !gListsGrowDown {
						index        = max
					}
				} else if     index  < max &&  (gListsGrowDown || index == 0) {
					index           += 1
				} else if     index  > 0    && (!gListsGrowDown || index == max) {
					index           -= 1
				}

				return siblings[index]
			} else {
				return parent
			}
		}

		return nil
	}

	func deleteZones(permanently: Bool = false, in iParent: Zone? = nil, iShouldGrab: Bool = true, onCompletion: Closure?) {
		if  count == 0 {
			onCompletion?()

			return
		}

		let    zones = sortedByReverseOrdering()
		let     grab = !iShouldGrab ? nil : grabAppropriate()
		var doneOnce = false

		for zone in self {
			zone.needProgeny()
		}

		if !doneOnce {
			doneOnce  = true
			var count = zones.count

			let finish: Closure = {
				grab?.grab()
				onCompletion?()
			}

			if  count == 0 {
				finish()
			} else {
				let deleteBookmarks: Closure = {
					count -= 1

					if  count == 0 {
						finish()

						gBatches.bookmarks { iSame in
							var bookmarks = ZoneArray ()

							for zone in zones {
								bookmarks += zone.fetchedBookmarks
							}

							if  bookmarks.count != 0 {

								// ///////////////////////////////////////////////////////////
								// remove any bookmarks the target of which is one of zones //
								// ///////////////////////////////////////////////////////////

								bookmarks.deleteZones(permanently: permanently, iShouldGrab: false) { // recurse
									finish()
								}
							}
						}
					}
				}

				for zone in zones {
					if  zone == iParent { // detect and avoid infinite recursion
						deleteBookmarks()
					} else {
						zone.deleteSelf(permanently: permanently) {
							deleteBookmarks()
						}
					}
				}
			}
		}
	}

	func whoseTargetIntersects(with iTargets: ZoneArray, orSpawnsIt: Bool = false) -> Zone? {
		var found: Zone?

		for target in iTargets {
			if  let                dbID = target.databaseID {
				var               level = Int.max
				for zone in self {
					if  let zoneTarget  = zone.bookmarkTarget,
						dbID           == zoneTarget.databaseID {
						let zoneLevel   = zoneTarget.level

						if  zoneTarget == target {
							return zone
						}

						if  orSpawnsIt,
							zoneLevel   < level,
							target.spawnedBy(zoneTarget) {
							level       = zoneLevel
							found       = zone
						}
					}
				}
			}
		}

		return found
	}

	func recursivelyRevealSiblings(untilReaching iAncestor: Zone, onCompletion: ZoneClosure?) {
		if  self.contains(iAncestor) {
			onCompletion?(iAncestor)

			return
		}

		var needRoot = true

		traverseAllAncestors { iParent in
			if  !self.contains(iParent) {
				iParent.expand()
				iParent.needChildren()
			}

			if  iParent == iAncestor {
				needRoot = false
			}
		}

		if  needRoot { // true means map in memory does not include root, so fetch it from iCloud
			for descendent in self {
				descendent.needRoot()
			}
		}

		traverseAncestors { iParent -> ZTraverseStatus in
			let  gotThere = iParent == iAncestor || iParent.isARoot    // reached the ancestor or the root
			let gotOrphan = iParent.parentZone == nil

			if  gotThere || gotOrphan {
				if !gotThere && !iParent.isFetched && iParent.parentZone != nil { // reached an orphan that has not yet been fetched
					[iParent].recursivelyRevealSiblings(untilReaching: iAncestor, onCompletion: onCompletion)
				} else {
					iAncestor.expand()
					FOREGROUND(after: 0.1) {
						onCompletion?(iAncestor)
					}
				}

				return .eStop
			}

			return .eContinue
		}
	}

}
