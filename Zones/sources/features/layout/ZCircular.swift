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

	func circularModeUpdateDotFrames(_ absolute: Bool) {
		if  absolute {
			for line in childrenLines {
				line.circularModeUpdateDotFrames(relativeTo: absoluteFrame, hideDragDot: hideDragDot)
			}
		}
	}

	func circularModeUpdateRange() {

	}

	// MARK: - static methods
	// MARK: -

	static func circularModeMaxVisibleSiblings(at level: Int, children: ZoneWidgetArray) -> Int {
		var maxVisible = 0

		for child in children {
			if  let  count = child.widgetZone?.count,
				maxVisible < count {
				maxVisible = count
			}
		}

		return 1
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

	static func circularModePlaceholderCount(at level: Int) -> Int {
		let children = circularModeVisibleChildren(at: level)
		let    count = children.count

		if  level == 0 {
			return count
		}

		let    siblings = circularModeMaxVisibleSiblings(at: level, children: children)

		return siblings * count * circularModePlaceholderCount(at: level - 1)
	}

	static func traverseWidgetsByLevel(_ block: IntZoneWidgetsClosure) {
		var   level = 0
		var widgets = circularModeVisibleChildren(at: level)

		while widgets.count != 0 {
			block(level, widgets)

			level  += 1
			widgets = circularModeVisibleChildren(at: level)
		}
	}

	// MARK: - traverse
	// MARK: -

	func circularModeUpdateFrames(_ absolute: Bool = false) {
		circularModeUpdateTextViewFrame(absolute)
		circularModeUpdateDotFrames    (absolute)
	}

	func circularModeUpdateAllFrames(in controller: ZMapController?, _ absolute: Bool = false) {
		ZoneWidget.traverseWidgetsByLevel { (level, widgets) in   // needed for updating text view frames
			let count = ZoneWidget.circularModePlaceholderCount(at: level)

			widgets.circularModeUpdateFrames(at: level, placeholderCount: count, in: controller, absolute)
		}

		traverseAllWidgetProgeny(inReverse: !absolute) { iWidget in
			iWidget.circularModeUpdateFrames(absolute)
		}
	}

	func circularModeGrandUpdate() {
		circularModeUpdateAllFrames(in: controller)
		updateFrameSize()
		circularModeUpdateAllFrames(in: controller, true)
		updateAbsoluteFrame(relativeTo: controller)
	}

}

// MARK: - widgets array
// MARK: -

extension ZoneWidgetArray {

	var circularModeScrollOffset : CGPoint { return CGPoint(x: -gScrollOffset.x, y: gScrollOffset.y + 21) }

	func circularModeUpdateFrames(at level: Int, placeholderCount: Int, in controller: ZMapController?, _ absolute: Bool = false) {
		circularModeUpdateRanges(absolute)
		circularModeUpdateCentralAngles(at: level, placeholderCount: placeholderCount, absolute)   // needed for updating text view frames
		circularModeUpdateWidgetFrames (at: level, in: controller, absolute)
	}

	func circularModeUpdateRanges(_ absolute: Bool = false) {
		if !absolute {
			for widget in self {
				widget.circularModeUpdateRange()
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
					let      angle = Double(line.centralAngle)
					let    rotated = CGPoint(x: radius, y: .zero).rotate(by: angle)
					let     origin = center + rotated - offset
					let       rect = CGRect(origin: origin, size:     .zero).expandedEquallyBy(half)
					widget .bounds = CGRect(origin:  .zero, size: rect.size)
					widget  .frame = rect
				}
			}
		}
	}

	func circularModeSpecificAngles(at level: Int, for count: Int) -> [Double] {
		let   offset = level == 0 ? 1.0 : 1.5
		let       pi = Double.pi
		let    start = pi / 2.0
		let   spread = pi * 2.0
		let   angles = count.anglesArray(startAngle: start, spreadAngle: spread, offset: offset, clockwise: true)

		return angles
	}

	func circularModeUpdateCentralAngles(at level: Int, placeholderCount: Int, _ absolute: Bool = false) {
		if  level     != 0 {
			let angles = circularModeSpecificAngles(at: level - 1, for: placeholderCount)

			// need ranges within placeholders

			if  angles.count > 0 {
				for (index, child) in enumerated() {
					child.parentLine?.centralAngle = CGFloat(angles[index])
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
		let radius = iRect.size.hypotenuse
		let  start = lineAngle.upward ? iRect.origin : iRect.topLeft
		let    end = CGPoint(x: radius, y: .zero).rotate(by: Double(lineAngle)).offsetBy(start)
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
			let   pCenter = l.parentWidget?.absoluteFrame.center,
			let   cCenter = l .childWidget?.absoluteFrame.center {
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
			l  .ringAngle = cToC.angle
			absoluteFrame = CGRect(origin: origin, size: drawnSize)

			updateTooltips()
		}
	}

	func circularModeDrawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
		let     angle = line?.lineAngle ?? 0.0
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
