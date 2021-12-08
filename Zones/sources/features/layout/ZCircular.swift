//
//  ZCircular.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/11/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

// MARK:- widget
// MARK:-

extension ZoneWidget {

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

	var circularModeHighlightFrame : CGRect {
		let center = absoluteFrame.center
		let radius = kDefaultCircularModeRadius + 3.0
		let   rect = CGRect(origin: center, size: .zero).insetEquallyBy(-radius)

		return rect
	}

	var circularModeSelectionHighlightPath: ZBezierPath {
		return ZBezierPath(ovalIn: highlightFrame)
	}

	func circularModeUpdateDotFrames(_ absolute: Bool) {
		if  absolute {
			for line in childrenLines {
				line.circularModeUpdateDotFrames(relativeTo: absoluteFrame, hideDragDot: hideDragDot)
			}
		}
	}

	static func circularModeRingRadius(at level: Int) -> CGFloat {
		let increment = kDefaultCircularModeRadius + gDotWidth + gDotHeight

		return CGFloat(level) * increment
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

	// MARK:- traverse
	// MARK:-

	static func traverseWidgetsByLevel(_ block: IntZoneWidgetsClosure) {
		var   level = 0
		var widgets = ZoneWidget.circularModeVisibleChildren(at: level)

		while widgets.count != 0 {
			block(level, widgets)

			level  += 1
			widgets = ZoneWidget.circularModeVisibleChildren(at: level)
		}
	}

	// this is called twice in grand update
	// first with absolute false, then with true

	func circularModeUpdateAllFrames(in controller: ZMapController?, _ absolute: Bool = false) {
		ZoneWidget.traverseWidgetsByLevel     { (level, widgets) in
			widgets.circularModeUpdateFrames(at: level, in: controller, absolute)   // needed for updating text view frames
		}

		traverseAllWidgetProgeny(inReverse: !absolute) { iWidget in
			iWidget.circularModeUpdateFrames(absolute)
		}
	}

	func circularModeUpdateFrames(_ absolute: Bool = false) {
		circularModeUpdateTextViewFrame(absolute)
		circularModeUpdateDotFrames    (absolute)
	}

	func circularModeGrandUpdate() {
		circularModeUpdateAllFrames(in: controller)
		updateFrameSize()
		circularModeUpdateAllFrames(in: controller, true)
		updateAbsoluteFrame(relativeTo: controller)
	}

}

// MARK:- widgets array
// MARK:-

extension ZoneWidgetArray {

	func circularModeUpdateFrames(at level: Int, in controller: ZMapController?, _ absolute: Bool = false) {
		circularModeUpdateVectors(at: level, absolute)   // needed for updating text view frames
		circularModeUpdateWidgetFrames(in: controller, absolute)
	}

	func circularModeUpdateWidgetFrames(in controller: ZMapController?, _ absolute: Bool = false) {
		if  let center = controller?.mapPseudoView?.frame.center {
			let   half = kDefaultCircularModeRadius
			let length = gDotHeight + (2.0 * (half + gDotWidth))
			let offset = CGPoint(x: -gScrollOffset.x, y: gScrollOffset.y + 21)

			for widget in self {
				if  absolute {
					widget.updateAbsoluteFrame(relativeTo: controller)
				} else if let line = widget.parentLine, widget.linesLevel > 0 {
					let     radius = length + line.length
					let      angle = Double(line.centerAngle)
					let    rotated = CGPoint(x: radius, y: .zero).rotate(by: angle)
					let     origin = center + rotated - offset
					let       rect = CGRect(origin: origin, size:     .zero).expandedEquallyBy(half)
					widget .bounds = CGRect(origin:  .zero, size: rect.size)
					widget  .frame = rect
				}
			}
		}
	}

	func circularModeSpecificAngles(at level: Int, for count: Int) -> (Double, Double, Double) {
		let         pi = Double.pi
		var      start = pi / 2.0
		var     offset = 1.0
		var     spread = pi * 2.0
		let  increment = pi / 6.0
		let   isCenter = level == 0

		if !isCenter {
			offset = 1.5
			spread = increment * Double(count)
			start += increment - spread / 2.0
		}

		return (start, spread, offset)
	}

	func circularModeUpdateVectors(at level: Int, _ absolute: Bool = false) {
		if  level != 0 {
			let (start, spread, offset) = circularModeSpecificAngles(at: level - 1, for: count)
			let                  angles = count.anglesArray(startAngle: start, spreadAngle: spread, offset: offset, clockwise: true)

			if  angles.count > 0 {
				for (index, child) in enumerated() {
					child.parentLine?.centerAngle = CGFloat(angles[index])
				}
			}
		}
	}

}

// MARK:- line
// MARK:-

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
		let  start = centerAngle.upward ? iRect.origin : iRect.topLeft
		let    end = CGPoint(x: radius, y: .zero).rotate(by: Double(centerAngle)).offsetBy(start)
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

// MARK:- dot
// MARK:-

extension ZoneDot {

	// reveal dot is at circle around text, at angle, drag dot is further out along same ray

	func circularModeUpdateDotAbsoluteFrame(relativeTo absoluteTextFrame: CGRect) {

		// length of vector = kDefaultCircularModeRadius + gDotWidth
		// longer for drag dot: add line length and dot width
		// rotate to angle (around zero point)
		// move zero point to text center
		// move further by size of dot

		if  let         l = line,
			let    center = l.parentWidget?.absoluteFrame.center {
			let     angle = Double(l.centerAngle)
			let    height = gDotWidth
			let     width = isReveal ? gDotHeight :      height
			let     extra = isReveal ? 0.0 : kDefaultCircularModeRadius +  height
			let      size = CGSize(width: width, height: height)
			let    radius = kDefaultCircularModeRadius + gDotWidth + extra
			let   rotated = CGPoint(x: radius, y: 0.0).rotate(by: angle)
			let    origin = center + rotated - size
			absoluteFrame = CGRect(origin: origin, size: drawnSize)

			updateTooltips()
		}
	}

	func circularModeDrawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
		let     angle = line?.centerAngle ?? 0.0
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
