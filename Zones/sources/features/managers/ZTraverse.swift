//
//  ZTraverse.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/23/22.
//  Copyright © 2022 Zones. All rights reserved.
//

import Foundation

typealias ZTraverseArray           = [ZTraverse]
typealias ZTraverseToStatusClosure = (ZTraverse) -> (ZTraverseStatus)

protocol ZTraverse {
	var  nextGeneration : ZTraverseArray { get }
	@discardableResult func traverseHierarchy(inReverse : Bool, _ closure: ZTraverseToStatusClosure) -> ZTraverseStatus
}

extension ZPseudoView : ZTraverse {
	var  nextGeneration : [ZTraverse] { return subpseudoviews }
	@discardableResult func traverseHierarchy(inReverse : Bool = false, _ block: ZTraverseToStatusClosure) -> ZTraverseStatus { return staticTraverseHierarchy(inReverse: inReverse, from: self, block) }
}

extension ZView : ZTraverse {
	var  nextGeneration : [ZTraverse] { return subviews }
	@discardableResult func traverseHierarchy(inReverse : Bool = false, _ block: ZTraverseToStatusClosure) -> ZTraverseStatus { return staticTraverseHierarchy(inReverse: inReverse, from: self, block) }
}

func staticTraverseHierarchy(inReverse : Bool = false, from: ZTraverse, _ block: ZTraverseToStatusClosure) -> ZTraverseStatus {
	var status = block(from)

	if  status == .eContinue {
		for child in from.nextGeneration {

			status = staticTraverseHierarchy(from: child, block)

			if  status == .eStop {
				break						// halt traversal
			}
		}
	}

	return status
}

extension Zone {

	func traverseAncestors(_ block: ZoneToStatusClosure) { safeTraverseAncestors(visited: [], block) }

	func traverseAllAncestors(_ block: @escaping ZoneClosure) {
		safeTraverseAncestors(visited: []) { iZone -> ZTraverseStatus in
			block(iZone)

			return .eContinue
		}
	}

	func safeTraverseAncestors(visited: ZoneArray, _ block: ZoneToStatusClosure) {
		if  block(self) == .eContinue,  //       skip == stop
			!isARoot,                   //    isARoot == stop
			!visited.contains(self),    //  map cycle == stop
			let p = parentZone {        // nil parent == stop
			p.safeTraverseAncestors(visited: visited + [self], block)
		}
	}

	@discardableResult func traverseProgeny(inReverse: Bool = false, _ block: ZoneToStatusClosure) -> ZTraverseStatus {
		return safeTraverseProgeny(visited: [], inReverse: inReverse, block)
	}

	func traverseAllVisibleProgeny(inReverse: Bool = false, _ block: ZoneClosure) {
		safeTraverseProgeny(visited: [], inReverse: inReverse) { iZone -> ZTraverseStatus in
			block(iZone)

			return iZone.isExpanded ? .eContinue : .eSkip
		}
	}

	func traverseAllProgeny(inReverse: Bool = false, _ block: ZoneClosure) {
		safeTraverseProgeny(visited: [], inReverse: inReverse) { iZone -> ZTraverseStatus in
			block(iZone)

			return .eContinue
		}
	}

	@discardableResult func safeTraverseProgeny(visited: ZoneArray, inReverse: Bool = false, _ block: ZoneToStatusClosure) -> ZTraverseStatus {
		var status  = ZTraverseStatus.eContinue

		if !inReverse {
			status  = block(self)               // first call block on self, then recurse on each child
		}

		if  status == .eContinue {
			for child in children {
				if  visited.contains(child) {
					break						// do not revisit or traverse further inward
				}

				status = child.safeTraverseProgeny(visited: visited + [self], inReverse: inReverse, block)

				if  status == .eStop {
					break						// halt traversal
				}
			}
		}

		if  inReverse {
			status  = block(self)
		}

		return status
	}

}

extension ZoneArray {

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

}

extension ZoneWidget {

	func traverseAllWidgetAncestors(visited: ZoneWidgetArray = [], _ block: ZoneWidgetClosure) {
		if !visited.contains(self) {
			block(self)
			parentWidget?.traverseAllWidgetAncestors(visited: visited + [self], block)
		}
	}

	func traverseAllVisibleWidgetProgeny(inReverse: Bool = false, _ block: ZoneWidgetClosure) {
		traverseAllWidgetProgeny(inReverse: inReverse) { widget in
			if  let zone = widget.widgetZone, zone.isVisible {
				block(widget)
			}
		}
	}

	func traverseAllWidgetProgeny(inReverse: Bool = false, _ block: ZoneWidgetClosure) {
		safeTraverseWidgetProgeny(visited: [], inReverse: inReverse) { widget -> ZTraverseStatus in
			block(widget)

			return .eContinue
		}
	}

	@discardableResult func traverseWidgetProgeny(inReverse: Bool = false, _ block: ZWidgetToStatusClosure) -> ZTraverseStatus {
		return safeTraverseWidgetProgeny(visited: [], inReverse: inReverse, block)
	}

	@discardableResult func safeTraverseWidgetProgeny(visited: ZoneWidgetArray, inReverse: Bool = false, _ block: ZWidgetToStatusClosure) -> ZTraverseStatus {
		var status  = ZTraverseStatus.eContinue

		if  visited.contains(self) {
			return status			        // do not revisit or traverse further inward
		}

		if !inReverse {
			status  = block(self)           // first call block on self, then recurse on each child

			if  status == .eStop {
				return status               // halt traversal
			}
		}

		for child in childrenWidgets {
			status = child.safeTraverseWidgetProgeny(visited: visited + [self], inReverse: inReverse, block)

			if  status == .eStop {
				return status               // halt traversal
			}
		}

		if  inReverse {
			status  = block(self)
		}

		return status
	}

	func traverseAllWidgetsByLevel(_ block: IntZoneWidgetsClosure) {
		var    level = 1
		var  widgets = childrenWidgets

		while widgets.count != 0 {
			block(level, widgets)

			level   += 1
			var next = ZoneWidgetArray()

			for widget in widgets {
				next.append(contentsOf: widget.childrenWidgets)
			}

			widgets  = next
		}
	}

}

extension ZWidgets {

	static func traverseAllVisibleWidgetsByLevel(_ block: IntZoneWidgetsClosure) {
		var   level = 0
		var widgets = visibleChildren(at: level)

		while widgets.count != 0 {
			block(level, widgets)

			level  += 1
			widgets = visibleChildren(at: level)
		}
	}

}
