//
//  ZoneArray.swift
//  Seriously
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

	var recordNames: StringsArray {
		var names = StringsArray()

		forEach { zone in
			if  let name = zone.recordName {
				names.append(name)
			}
		}

		return names
	}

	var containsARoot : Bool {
		return applyBooleanToZone { zone in
			return zone.isARoot
		}
	}

	var userCanMoveAll: Bool {
		return applyBooleanToZone(requiresAll: true) { zone in
			return zone.userCanMove
		}
	}

	func applyBooleanToZone(requiresAll: Bool = false, closure: ZoneToBooleanClosure) -> Bool {
		for zone in self {
			if  closure(zone) != requiresAll {
				return !requiresAll
			}
		}

		return requiresAll
	}

	func anyParentMatches(_ zone: Zone) -> Bool {
		return applyBooleanToZone { zone in
			return zone.parentZone == zone
		}

	}

	func containsMatch(to other: AnyObject) -> Bool {
		return containsCompare(with: other) { (a, b) in
			if  let    aName  = (a as? Zone)?.recordName,
				let    bName  = (b as? Zone)?.recordName {
				return aName ==  bName
			}

			return false
		}
	}

	func updateOrder() { updateOrdering(start: 0.0, end: 1.0) }

	func orderLimits() -> (start: Double, end: Double) {
		var start = 1.0
		var   end = 0.0

		forEach { zone in
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
			}
		}

		gSelecting.updateCousinList()
	}

	func traverseAncestors(_ block: ZoneToStatusClosure) {
		forEach { zone in
			zone.safeTraverseAncestors(visited: [], block)
		}
	}

	func traverseAllAncestors(_ block: @escaping ZoneClosure) {
		forEach { zone in
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
			var candidates = ZoneArray()
			var      order = goingUp ? 1.0 : 0.0
			var      level = candidate?.level ?? Int.max

			for zone in self {
				let zLevel      = zone.level
				if  level      == zLevel {
					candidates.append(zone)
				} else if level > zLevel {
					level       = zLevel
					candidate   =  zone
					candidates  = [zone]
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

		forEach { zone in
			if  candidate == nil || zone.level < candidate!.level {
				candidate = zone
			}
		}

		return candidate
	}

	mutating func duplicate() {
		var duplicated = ZoneArray ()
		var    indices = [Int] ()

		sort { (a, b) -> Bool in
			return a.order < b.order
		}

		forEach { zone in
			if  let     index = zone.siblingIndex {
				let duplicate = zone.deepCopy(dbID: nil)

				duplicated.append(duplicate)
				indices   .append(index)
			}
		}

		while   var index = indices.last, let duplicate = duplicated.last, let zone = last {
			if  let     p = zone.parentZone {
				index    += (gListsGrowDown ? 1 : 0)

				p.addChild(duplicate, at: index)
				p.children.updateOrder()
				duplicate.grab()
			}

			duplicated.removeLast()
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
			}

			gSelecting.hasNewGrab = gSelecting.currentMoveable
		}
	}

	func cycleToNextDuplicate() {
		forEach { zone in
			zone.cycleToNextDuplicate()
		}

		gRelayoutMaps()
	}

	func deleteDuplicates() {
		forEach { zone in
			zone.deleteDuplicates()
		}

		gRelayoutMaps()
	}

	func sortBy(_ type: ZReorderMenuType, _ iBackwards: Bool) {
		switch type {
			case .eAlphabetical: alphabetize   (iBackwards)
			case .eBySizeOfList: sortByCount   (iBackwards)
			case .eByLength:     sortByLength  (iBackwards)
			case .eByKind:       sortByZoneType(iBackwards)
			case .eReversed:     reverse()
		}
	}

	func reverse() {
		var        zones  = self
		let commonParent  = zones.commonParent

		if  commonParent == nil {
			return
		}

		if  zones.count  == 1 {
			zones         = commonParent?.children ?? []
		}

		commonParent?.respectOrder()
		commonParent?.children.updateOrder()
		zones        .reverseOrder()
		commonParent?.respectOrder()
		gRelayoutMaps()
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

	func sortByCount(_ iBackwards: Bool = false) {
		alterOrdering { iZones -> (ZoneArray) in
			return iZones.sorted { (a, b) -> Bool in
				let aCount = a.count
				let bCount = b.count

				return iBackwards ? (aCount > bCount) : (aCount < bCount)
			}
		}
	}

	func sortByZoneType(_ iBackwards: Bool = false) {
		alterOrdering { iZones -> (ZoneArray) in
			return iZones.sorted { (a, b) -> Bool in
				let aType = a.zoneType.rawValue
				let bType = b.zoneType.rawValue

				return aType > bType
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
				gRelayoutMaps()
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

	var appropriateParent: Zone? {
		var into = rootMost?.parentZone                             // default: move into parent of root most
		if  count > 0,
			let siblings = into?.children {
			var  fromTop = false

			for zone in self {
				if  let    index = zone.siblingIndex {
					fromTop      = fromTop || index == 0                               // detect when moving the top sibling
					if  let zone = siblings.next(from: index, forward: !fromTop),      // always move into sibling above, except at top
						!contains(zone) {
						into     = zone

						break
					}
				}
			}
		}

		return into
	}

	func actuallyMoveInto(onCompletion: BoolClosure?) {
		if  let into = appropriateParent {
			into.expand()
			moveIntoAndGrab(into, onCompletion: onCompletion)
		} else {
			onCompletion?(true)
		}
	}

	func moveIntoAndGrab(_ into: Zone, at iIndex: Int? = nil, orphan: Bool = true, onCompletion: BoolClosure?) {
		if  into.isInSmallMap {
			into.parentZone?.collapse()

			gCurrentSmallMapRecords?.hereZoneMaybe = into
		}

		gSelecting.ungrabAll()

		let zones = gListsGrowDown ? self : self.reversed()

		for     zone in zones {
			if  zone != into {
				if  orphan {
					zone.orphan()
				}

				into.addChildAndReorder(zone, at: iIndex)
				zone.addToGrabs()
			}
		}

		onCompletion?(true)
	}

	var forDetectingDuplicates: ZoneArray? {
		var grabs          = ZoneArray()
		if  count          > 1 {
			return self
		} else if count    > 0 {                           // only one zone is grabbed
			let grab       = self[0]

			if  grab.count > 1 { // has children
				grabs      = grab.children

				grab.expand()
			} else if let siblings = grab.parentZone?.children {
				if  siblings.count == 0 {  // no siblings
					return nil             // no chance of duplicates
				}

				grabs = siblings
			}
		}

		return grabs
	}

	func grabDuplicates() -> Bool {
		var originals = StringsArray()
		var found = false

		for (index, zone) in self.enumerated() {
			if  let name = zone.zoneName {
				if !originals.contains(name) {
					originals  .append(name)
				} else {
					found = true

					if zone.count < 2 {
						gSelecting.addOneGrab(zone)
					} else {
						var i         = index
						while i       > 0 {
							i        -= 1
							let prior = self[i]

							if  name == prior.zoneName {
								gSelecting.addOneGrab(prior)
							}
						}
					}
				}

				if  zone.count > 1,
					zone.children.grabDuplicates() {
					zone.expand()

					found = true
				}
			}
		}

		return found
	}

	func grabAppropriate() -> Zone? {
		let         down = gListsGrowDown
		let           up = !down
		if  let   parent = first?.parentZone {
			let siblings = parent.children
			var    count = siblings.count
			let      max = count - 1

			for zone in self {
				if  siblings.contains(zone) {
					count -= 1
				}
			}

			if  max <= 0 || count <= 0 {
				return parent
			} else if let firstX = first!.siblingIndex,
					  let  lastX =  last!.siblingIndex {
				var        index = up ? firstX : lastX
				if       firstX == 0,    lastX < max {
					index        = lastX + 1
				} else if lastX == max, firstX > 0 {
					index        = firstX - 1
				} else if index == max &&  down {
					index        = 0
				} else if index == 0   &&  up {
					index        = max
				} else if index  < max && (down || index == 0) {
					index       += 1
				} else if index  > 0   && (up   || index == max) {
					index       -= 1
				}

				return siblings[index]
			}
		}

		return nil
	}

	func copyToPaste() {
		gSelecting.clearPaste()

		forEach { zone in
			zone.addToPaste()
		}
	}

	func deleteZones(permanently: Bool = false, in iParent: Zone? = nil, iShouldGrab: Bool = true, onCompletion: Closure?) {
		if  count == 0 {
			onCompletion?()

			return
		}

		let    zones = sortedByReverseOrdering()
		let     grab = !iShouldGrab ? nil : grabAppropriate()
		var doneOnce = false

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
								bookmarks += zone.bookmarksTargetingSelf
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

	func whoseTargetIntersects(with iTargets: ZoneArray, orSpawnsIt: Bool) -> Zone? {
		for target in iTargets {
			if  let                dbid = target.dbid {
				for zone in self {
					if  let  zoneTarget = zone.bookmarkTarget,
						dbid           == zoneTarget.dbid {

						if  zoneTarget == target || (orSpawnsIt && target.spawnedBy(zoneTarget)) {
							return zone
						}
					}
				}
			}
		}

		return nil
	}

	func recursivelyRevealSiblings(untilReaching iAncestor: Zone, onCompletion: ZoneClosure?) {
		if  self.contains(iAncestor) {
			onCompletion?(iAncestor)

			return
		}

		traverseAllAncestors { iParent in
			if  !self.contains(iParent) {
				iParent.expand()
			}
		}

		traverseAncestors { iParent -> ZTraverseStatus in
			let  gotThere = iParent == iAncestor || iParent.isARoot    // reached the ancestor or the root
			let gotOrphan = iParent.parentZone == nil

			if  gotThere || gotOrphan {
				if !gotThere && iParent.parentZone != nil { // reached an orphan that has not yet been fetched
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

	mutating func toggleGroupOwnership() {
		let groupOwner = Zone.uniqueZone(recordName: nil, in: .mineID)

		for child in self {
			if  child.isAGroupOwner {                    // remove .groupOwner from attributes
				child.alterAttribute(.groupOwner, remove: true)
				gRelayoutMaps()

				return                                  // abandon groupOwner created above
			}

			if  child.isBookmark {
				child.orphan()                          // move from current parent
				groupOwner.addChildNoDuplicate(child)   // into groupOwner
			} else {
				gNewOrExistingBookmark(targeting: child, addTo: groupOwner)
			}
		}

		gSmallMapMode = .favorites                      // switch to favorites

		gCurrentSmallMapRecords?.showRoot()             // point here to root, and expand
		groupOwner.alterAttribute(.groupOwner, remove: false)
		gFavorites.insertAsNext(groupOwner)
		gRelayoutMaps()
		groupOwner.edit()
	}

}
