//
//  ZCircular.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/11/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

// MARK: - widget
// MARK: -

extension ZoneWidget {

	var circularModeHighlightFrame : CGRect {
		let center = absoluteFrame.center
		let radius = gCircularModeRadius + 3.0
		let   rect = CGRect(origin: center, size: .zero).insetEquallyBy(-radius)

		return rect
	}

	var circularModeSelectionHighlightPath: ZBezierPath {
		return ZBezierPath(ovalIn: highlightFrame)
	}

	func circularModeUpdateWidgetDrawnSize() {
		if  let  size = textWidget?.frame.size {
			drawnSize = size.insetBy(gDotHeight, gDotHeight)
		}
	}

	func circularModeUpdateTextViewFrame(_ absolute: Bool = false) {
		if  let                 t = pseudoTextWidget {
			if  absolute {
				t.updateAbsoluteFrame(relativeTo: controller)

				textWidget?.frame = t.absoluteFrame
			} else if let    size = textWidget?.drawnSize {
				let          half = size.multiplyBy(0.5)
				let        center = bounds.center
				let          rect = CGRect(origin: center, size: .zero).expandedBy(half)
				t          .frame = rect
			}
		}
	}

	func circularModeUpdateAllDotFrames(_ absolute: Bool) {
		if  absolute {
			for line in childrenLines {
				line.circularModeUpdateDotFrames(relativeTo: absoluteFrame, hideDragDot: hideDragDot)
			}
		}
	}

	func circularModeUpdatePlaceOffset() {
		if  let           zone = widgetZone, zone.hasVisibleChildren,
			let          angle = parentLine?.placeAngle,                   // TODO: placeAngle is zero
			let    placesCount = angles(at: linesLevel + 1)?.count {
			let       pieSlice = (angle / k2PI).confine(within: 1)
			if     placesCount > 0 {
				let placeIndex = Double(placesCount) * pieSlice
				let     spread = (zone.count - 1) * placeCadence
				let     offset = (placeIndex - (Double(spread) / 2.0)).roundedToNearestInt.confine(within: placesCount)
				placeOffset    = offset

				print("o  \(linesLevel) \(placesCount) * (\((pieSlice * 360).roundedToNearestInt) deg) = \(offset) \(zone)")
			}
		}
	}

	func circularModeUpdatePlaceAngle(at index: Int) {
		var     angle  = Double.zero
		if  let angles = angles(at: linesLevel), angles.count > 0,
			let zi     = widgetZone?.siblingIndex {
			let count  = angles.count
			var     i  = index
			if  let p  = parentWidget {
				let o  = p.placeOffset
				let c  = p.placeCadence
				i      = (o + (zi * c)).confine(within: count)

//				print(" a \(linesLevel) \(o) \(index) \(i) \(self)")
			}

//			let d = linesLevel < 2 ? CGFloat.zero : kHalfPI

			angle = (angles[i]).confine(within: k2PI)
		}

		parentLine?.placeAngle = CGFloat(angle)

		circularModeUpdatePlaceOffset() // used by next level
	}

	// MARK: - static methods
	// MARK: -

	static func circularModeMaxVisibleChildren(at level: Int) -> Int {
		let   children = circularModeVisibleChildren(at: level)
		var maxVisible = 0

		for child in children {
			if  let  count = child.widgetZone?.visibleChildren.count,
				maxVisible < count {
				maxVisible = count
			}
		}

		return maxVisible
	}

	static func circularModeVisibleChildren(at level: Int) -> ZoneWidgetArray {
		var widgets = ZoneWidgetArray()

		for widget in gHere.visibleWidgets {
			if  widget.linesLevel == level {
				widgets.append(widget)
			}
		}

		return widgets
	}

	static func circularModeRingRadius(at level: Int) -> CGFloat {
		let    thrice = gCircularModeRadius * 2.5
		let increment = gDotWidth + thrice + gDotHeight
		let     start = gDotWidth / 2.0

		return  start + (CGFloat(level) * increment)
	}

	static func circularModePlacesCount(at iLevel: Int) -> Int {
		var level = iLevel
		var total = 1

		while true {
			let cCount = circularModeMaxVisibleChildren(at: level)
			total     *= cCount
			level     -= 1

			if  level  < 0 {
				return total
			}
		}
	}

	static func traverseAllWidgetsByLevel(_ block: IntZoneWidgetsClosure) {
		var   level = 0
		var widgets = circularModeVisibleChildren(at: level)

		while widgets.count != 0 {
			block(level, widgets)

			level  += 1
			widgets = circularModeVisibleChildren(at: level)
		}
	}

	func circularModeSpecificAngles(at level: Int, for count: Int) -> [Double] {
		let   offset = level <= 1 ? 0.0 : 1.5
		let    start = kHalfPI
		let   spread = k2PI
		let   angles = count.anglesArray(startAngle: start, spreadAngle: spread, offset: offset, clockwise: true)

		return angles
	}

	// MARK: - traverse
	// MARK: -

	func circularModeUpdateFrames(_ absolute: Bool = false) {
		circularModeUpdateTextViewFrame(absolute)
		circularModeUpdateAllDotFrames (absolute)
	}

	func circularModeUpdateByLevelAllFrames(in controller: ZMapController?, _ absolute: Bool = false) {
		ZoneWidget.traverseAllWidgetsByLevel { (level, widgets) in
			let                placesCount = ZoneWidget.circularModePlacesCount(at: level - 1)
			controller?.placeAngles[level] =         circularModeSpecificAngles(at: level - 1,     for: placesCount)
			widgets.circularModeUpdateAllWidgetFrames                          (at: level, placesCount: placesCount, in: controller, absolute)
		}

		traverseAllWidgetProgeny(inReverse: !absolute) { iWidget in
			iWidget.circularModeUpdateFrames(absolute)  // sets lineAngle
		}
	}

	func circularModeGrandUpdate() {
		circularModeUpdateByLevelAllFrames(in: controller)
		updateFrameSize()
		circularModeUpdateByLevelAllFrames(in: controller, true)
		updateAbsoluteFrame(relativeTo: controller)
	}

}

// MARK: - widgets array
// MARK: -

extension ZoneWidgetArray {

	var circularModeScrollOffset : CGPoint { return CGPoint(x: -gScrollOffset.x, y: gScrollOffset.y + 21) }

	func circularModeUpdateAllWidgetFrames(at  level: Int, placesCount: Int, in controller: ZMapController?, _ absolute: Bool = false) {
		circularModeUpdateAllPlaceAngles  (at: level,     placesCount: placesCount, absolute)   // needs placeOffset, needed for text frames
		circularModeUpdateWidgetFrames    (at: level, in: controller,               absolute)   // needs placeAngle
	}

	func circularModeUpdateAllPlaceAngles(at level: Int, placesCount: Int, _ absolute: Bool = false) {
		if  level != 0, !absolute {
			for (index, child) in enumerated() {
				child.circularModeUpdatePlaceAngle(at: index)
			}
		}
	}

	func circularModeUpdateWidgetFrames(at level: Int, in controller: ZMapController?, _ absolute: Bool = false) {
		if  let center = controller?.mapPseudoView?.frame.center {
			let   half = gCircularModeRadius
			let offset = circularModeScrollOffset
			let radius = ZoneWidget.circularModeRingRadius(at: level)

			for widget in self {
				if  absolute {
					widget.updateAbsoluteFrame(relativeTo: controller)
				} else if let line = widget.parentLine, widget.linesLevel > 0 {
					let      angle = Double(line.placeAngle)
					let    rotated = CGPoint(x: .zero, y: radius).rotate(by: angle)
					let     origin = center + rotated - offset
					let       rect = CGRect(origin: origin, size:     .zero).expandedEquallyBy(half)
					widget .bounds = CGRect(origin:  .zero, size: rect.size)
					widget  .frame = rect

//					print(" w \(widget.linesLevel) \(angle.stringTo(precision: 1)) \(widget)")
				}
			}
		}
	}

}

// MARK: - line
// MARK: -

extension ZoneLine {

	var circularModeLineRect : CGRect {
		return .zero // TODO: compute this
	}

	var circularModeAbsoluteDropDotRect: CGRect {
		var rect = CGRect()

		if  let zone = parentWidget?.widgetZone {
			if !zone.hasVisibleChildren {

				// //////////////////////
				// DOT IS STRAIGHT OUT //
				// //////////////////////

				if  let            dot = revealDot {
					let         insetX = CGFloat((gDotHeight - gDotWidth) / 2.0)
					rect               = dot.absoluteActualFrame.insetBy(dx: insetX, dy: 0.0).offsetBy(dx: gGenericOffset.width, dy: 0.0)
				}
			} else if let      indices = gDropIndices, indices.count > 0 {
				let         firstindex = indices.firstIndex

				if  let       firstDot = parentWidget?.dot(at: firstindex) {
					rect               = firstDot.absoluteActualFrame
					let      lastIndex = indices.lastIndex

					if  indices.count == 1 || lastIndex >= zone.count {

						// ////////////////////////
						// DOT IS ABOVE OR BELOW //
						// ////////////////////////

						let   relation = gDragRelation
						let    isAbove = relation == .above || (!gListsGrowDown && (lastIndex == 0 || relation == .upon))
						let multiplier = CGFloat(isAbove ? 1.0 : -1.0) * kVerticalWeight
						let    gHeight = gGenericOffset.height
						let      delta = (gHeight + gDotWidth) * multiplier
						rect           = rect.offsetBy(dx: 0.0, dy: delta)

					} else if lastIndex < zone.count, let secondDot = parentWidget?.dot(at: lastIndex) {

						// ///////////////
						// DOT IS TWEEN //
						// ///////////////

						let secondRect = secondDot.absoluteActualFrame
						let      delta = (rect.minY - secondRect.minY) / CGFloat(2.0)
						rect           = rect.offsetBy(dx: 0.0, dy: -delta)
					}
				}
			}
		}

		return rect
	}

	func circularModeUpdateDotFrames(relativeTo absoluteTextFrame: CGRect, hideDragDot: Bool) {
		dragDot?  .circularModeUpdateDotAbsoluteFrame(relativeTo: absoluteTextFrame)
		revealDot?.circularModeUpdateDotAbsoluteFrame(relativeTo: absoluteTextFrame)
	}

	func circularModeStraightLinePath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
		let   path = ZBezierPath()
		let  start = iRect.origin
		let radius = iRect.size.hypotenuse
		let    end = CGPoint(x: .zero, y: radius).rotate(by: Double(relevantAngle)).offsetBy(start)
		let   clip = CGRect(start: start, extent: end).expandedEquallyBy(10.0)

		path.move(to: start)
		path.line(to: end)

		if  gDebugDraw {
			clip.drawColoredRect(.green)
		}

		return path
	}

	func circularModeUpdateLineSize() {
		// TODO: use radius to create point (vector)
		// use angle to rotate
		// use this to create drawnSize
	}

}

// MARK: - dot
// MARK: -

extension ZoneDot {

	// reveal dot is at circle around text, at angle, drag dot is further out along same ray

	func circularModeUpdateDotAbsoluteFrame(relativeTo absoluteTextFrame: CGRect) {

		// line's angle and length determined by centers of parent and child widget

		if  let         l = line,
			let   pCenter = l.parentWidget?.frame.center,
			let   cCenter = l .childWidget?.frame.center {
			let      cToC = cCenter - pCenter
			let    length = cToC.length
			let     width = isReveal ? gDotHeight : gDotWidth
			let      size = CGSize(width: width, height: gDotWidth)
			let    radius = gCircularModeRadius + (width / 1.5) + 1.5
			let   divisor = isReveal ? radius : (length - radius)
			let     ratio = divisor / length
			let    offset = cToC * ratio
			let    origin = pCenter + offset - size
			l     .length = radius
			l  .lineAngle = cToC.angle             //  sets lineAngle
			absoluteFrame = CGRect(origin: origin, size: drawnSize)

			updateTooltips()
		}
	}

	func circularModeDrawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
		let     angle = line?.relevantAngle ?? 0.0
		let thickness = CGFloat(gLineThickness * 2.0)
		let      rect = iDirtyRect.insetEquallyBy(thickness)
		var      path = ZBezierPath()

		if  parameters.isReveal {
			path      = ZBezierPath.bloatedTrianglePath(in: rect, at: angle)
		} else {
			path      = ZBezierPath           .ovalPath(in: rect, at: angle)
		}

		path.lineWidth = thickness
		path .flatness = 0.0001

		path.stroke()
		path.fill()

//		if  let z = widgetZone, gDebugDraw { // for debugging hover
//			print("drawing \(isReveal ? "REVEAL" : "DRAG  ") dot for \"\(z)\"\(parameters.filled ? " FILLED" : "")\(isHovering ? " HOVER" : "")")
//		}
	}

}
