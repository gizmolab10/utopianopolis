//
//  ZoneArray.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/22/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

extension ZoneArray {

	func printSelf() { print(self) }
	func grab() { gSelecting.ungrabAll(retaining: self) }

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

	func anyParentMatches(_ iZone: Zone) -> Bool {
		return applyBooleanToZone { zone in
			return zone.parentZone == iZone
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

	func updateOrder() { updateOrdering(start: .zero, end: 1.0) }

	func orderLimits() -> (start: Double, end: Double) {
		var start = 1.0
		var   end = Double.zero

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
		if  gWhileMigratingFromCloudKit { return }

		let increment = (end - start) / Double(count + 2)

		for (index, child) in enumerated() {
			let newOrder = start + (increment * Double(index + 1))
			let    order = child.order

			if  order      != newOrder {
				child.order = newOrder
			}
		}

		gSelecting.updateCousinList()
	}

	func rootMost(goingUp: Bool) -> Zone? {
		guard count > 0 else { return nil }

		var      candidate = first

		if count > 1 {
			var candidates = ZoneArray()
			var      order = goingUp ? 1.0 : .zero
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

	mutating func respectOrderAndLevelValues() {
		sort { (a, b) -> Bool in
			if  a.level == b.level {
				return a.order < b.order
			} else {
				return a.level < b.level // compare levels from multiple parents
			}
		}
	}

	mutating func reorderAccordingToValue() { // was respectOrder
		sort { (a, b) -> Bool in
			return a.order < b.order
		}
	}

	mutating func duplicate() {
		var duplicated = ZoneArray ()
		var    indices =  IntArray ()

		reorderAccordingToValue()

		forEach { zone in
			if  let     index = zone.siblingIndex {
				let duplicate = zone.deepCopy(into: nil)

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

		gFavoritesCloud.updateFavoritesAndRedraw()
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

			gSelecting.updateCousinList(for: gSelecting.currentMoveable)
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

	func sortBy(_ type: ZReorderMenuType, _ iBackwards: Bool = false, inParent: Zone? = nil) {
		if  let parent = inParent {
			switch type {
				case .eReversed:     reverse       (parent)
				case .eAlphabetical: alphabetize   (parent, iBackwards)
				case .eBySizeOfList: sortByCount   (parent, iBackwards)
				case .eByLength:     sortByLength  (parent, iBackwards)
				case .eByKind:       sortByZoneType(parent, iBackwards)
				case .eByDate:       sortByDate    (parent, iBackwards)
			}
		} else {
			for (parent, children) in parentsAndChildren {
				children.sortBy(type, iBackwards, inParent: parent)   // recurse
			}
		}
	}

	func sortAccordingToKey(_ key: String, _ reversed: Bool = false) {
		if  let type  = ZReorderMenuType(rawValue: key) {
			sortBy(type, reversed)
		}
	}

	func reverse(_ parent: Zone) {
		alterOrdering(inParent: parent) { iZones -> (ZoneArray) in
			var  result = ZoneArray()
			var   index = count

			while index > 0 {
				index  -= 1

				result.append(self[index])
			}

			return result
		}
	}

	func alphabetize(_ parent: Zone, _ iBackwards: Bool = false) {
		alterOrdering(inParent: parent) { iZones -> (ZoneArray) in
			return iZones.sorted { (a, b) -> Bool in
				let aName = a.unwrappedName
				let bName = b.unwrappedName

				return iBackwards ? (aName > bName) : (aName < bName)
			}
		}
	}

	func sortByCount(_ parent: Zone, _ iBackwards: Bool = false) {
		alterOrdering(inParent: parent) { iZones -> (ZoneArray) in
			return iZones.sorted { (a, b) -> Bool in
				let aCount = a.count
				let bCount = b.count

				return iBackwards ? (aCount > bCount) : (aCount < bCount)
			}
		}
	}

	func sortByDate(_ parent: Zone, _ iBackwards: Bool = false) {
		alterOrdering(inParent: parent) { iZones -> (ZoneArray) in
			return iZones.sorted { (a, b) -> Bool in
				if  let aDate = a.modificationDate,
					let bDate = b.modificationDate {

					return iBackwards ? (aDate > bDate) : (aDate < bDate)
				}

				return false // not alter order
			}
		}
	}

	func sortByZoneType(_ parent: Zone, _ iBackwards: Bool = false) {
		alterOrdering(inParent: parent) { iZones -> (ZoneArray) in
			return iZones.sorted { (a, b) -> Bool in
				let aType = a.zoneType.rawValue
				let bType = b.zoneType.rawValue

				return aType > bType
			}
		}
	}

	func sortByLength(_ parent: Zone, _ iBackwards: Bool = false) {
		let font = gMainFont

		alterOrdering(inParent: parent) { iZones -> (ZoneArray) in
			return iZones.sorted { (a, b) -> Bool in
				let aLength = a.widget?.textWidget?.text?.widthForFont(font) ?? .zero
				let bLength = b.widget?.textWidget?.text?.widthForFont(font) ?? .zero

				return iBackwards ? (aLength > bLength) : (aLength < bLength)
			}
		}
	}

	var parentsAndChildren : [Zone : ZoneArray] {
		var parents =        [Zone : ZoneArray]()

		for zone in self {
			if  let   parent = zone.parentZoneMaybe {
				var children = parents[parent] ?? ZoneArray()

				children.append(zone)

				parents[parent] = children
			}
		}

		return parents
	}

	mutating func replace(_ zones: ZoneArray) {
		var indices = IndexPath()
		var new = 0

		for zone in zones {
			if  let index = firstIndex(of: zone) {
				indices.append(index)
			}
		}

		indices.sort()

		for old in indices {
			self[old] = zones[new]
			new      += 1
		}
	}

	func alterOrdering(_ iBackwards: Bool = false, inParent: Zone, with sort: ZonesToZonesClosure) {
		if  count > 1 {
			var        zones = self
			let (start, end) = orderLimits()

			zones = sort(zones)

			zones.updateOrdering(start: start, end: end)
			inParent.children.replace(zones)
			inParent.respectOrder()
			inParent.children.updateOrder()
			gSelecting.updateCousinList(for: gSelecting.currentMoveable)
			gRelayoutMaps()
		}
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

	func assureZoneAdoption() {
		traverseAllAncestors { ancestor in
			ancestor.adopt()
		}
	}

	var appropriateParent: Zone? {
		var into = rootMost?.parentZone                                                  // default: move into parent of root most
		if  count > 0,
			let siblings = into?.children {
			var  fromTop = false

			for zone in self {
				if  let    index = zone.siblingIndex {
					fromTop      = fromTop || index == 0                                 // detect when moving the top sibling
					if  let zone = siblings.next(goingDown: fromTop, from: index),      // always move into sibling above, except at top
						!contains(zone) {
						into     = zone

						break
					}
				}
			}
		}

		return into
	}

	func actuallyMoveRight(_ flags: ZEventFlags? = nil, onCompletion: BoolClosure?) {
		let CONTROL = flags?.hasControl ?? false

		guard let parent = appropriateParent else {
			onCompletion?(true)

			return
		}

		if  CONTROL {
			parent.expand()
		}

		moveRight(into: parent, horizontal: true, grab: CONTROL || parent.isExpanded, onCompletion: onCompletion)
	}

	func moveRight(into: Zone, at iIndex: Int? = nil, orphan: Bool = true, horizontal: Bool = false, travel: Bool = false, grab: Bool = true, onCompletion: BoolClosure?) {
		if  into.isInFavorites, travel {
			into.parentZone?.collapse()

			gFavoritesCloud.hereZoneMaybe = into
		}

		gSelecting.ungrabAll()

		let zones = (gListsGrowDown || !horizontal) ? self : reversed()

		for     zone in zones {
			if  zone != into {
				if  orphan {
					zone.orphan()
				}

				into.addChildAndUpdateOrder(zone, at: iIndex)

				if  grab {
					zone.addToGrabs()
				} else {
					into.addToGrabs()
				}
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
			} else if let siblings = grab.siblings {
				if  siblings.count == 0 {  // no siblings
					return nil             // no chance of duplicates
				}

				grabs = siblings
			}
		}

		return grabs
	}

	func setZoneNameForAll(_ name: String) {
		for zone in self {
			zone.setName(to: name)
		}
	}

	func grabDuplicates() -> Bool {
		var originals = StringsArray()
		var found = false

		for (index, zone) in enumerated() {
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

	var appropriateNext : Zone? {
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

				if  index > max {
					index = max
				} else if index < 0 {
					index = 0
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

		let  grab = !iShouldGrab ? nil : appropriateNext
		let zones = sortedByReverseOrdering()
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

							// //////////////////////////////////////////////////////// //
							// remove any bookmarks the target of which is one of zones //
							// //////////////////////////////////////////////////////// //

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
					zone.deleteSelf(permanently: permanently) { flag in
						deleteBookmarks()
					}
				}
			}
		}

		gFavoritesCloud.resetRecents()
	}

	var firstUndeleted : Zone? {
		for zone in self {
			if !zone.isDeleted {
				return zone
			}
		}

		return nil
	}

	func whoseTargetIntersects(with iTargets: ZoneArray, orSpawnsIt: Bool = false) -> ZoneArray {
		var intersection = ZoneArray()
		for target in iTargets {
			if  let       dbid = target.dbid,
				let targetLink = target.asZoneLink {
				for zone in self {
					if  let zoneLink = zone.zoneLink, !zone.isDeleted,
						dbid        == zoneLink.maybeDatabaseID?.identifier {

						if  targetLink == zoneLink || (orSpawnsIt && target.isProgenyOf(zone.bookmarkTarget)) {
							intersection.append(zone)
						}
					}
				}
			}
		}

		return intersection
	}

	func recursivelyRevealSiblings(untilReaching iAncestor: Zone, onCompletion: ZoneClosure?) {
		if  contains(iAncestor) {
			onCompletion?(iAncestor)

			return
		}

		traverseAllAncestors { iParent in
			if  !contains(iParent) {
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
				ZBookmarks.newOrExistingBookmark(targeting: child, addTo: groupOwner)
			}
		}

		gFavoritesCloud.showRoot()                           // point here to root, and expand
		groupOwner.alterAttribute(.groupOwner, remove: false)
		gFavoritesCloud.insertAsNext(groupOwner)
		FOREGROUND(after: 0.1) {
			gRelayoutMaps()
			groupOwner.edit()
		}
	}

	func applyMutator(_ type: ZMutateTextMenuType) {
		for zone in self {
			zone.applyMutator(type)
		}
	}

	func generationalGoal(_ show: Bool, extreme: Bool = false) -> Int? {
		var goal = 0

		if  show && extreme {
			return Int.max
		}

		for zone in self {
			if !show {
				let g = extreme ? zone.level : zone.highestExposed - 1
				if  g > goal {
					goal = g
				}
			} else if let lowest = zone.lowestExposed, lowest + 1 > goal {
				goal = lowest + 1
			}
		}

		return goal
	}

	func applyGenerationally(_ show: Bool, extreme: Bool = false) {
		let goal = generationalGoal(show, extreme: extreme)

		for zone in self {
			zone.generationalUpdate(show: show, to: goal)
		}

		gRelayoutMaps()
	}

}
