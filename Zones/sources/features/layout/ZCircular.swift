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

	var                   placesCount :         Int { return ZoneWidget.placesCount(at: linesLevel) }
	var circlesSelectionHighlightPath : ZBezierPath { return ZBezierPath(ovalIn: highlightFrame) }
	var                incrementAngle :     CGFloat { return k2PI / CGFloat(placesCount) }

	var placeAngle : CGFloat {
		var angle  = offsetAngle
		if  let p  = parentWidget, !isCenter {
			let o  = p.placeAngle
			angle += o
		}

		return angle
	}

	var offsetAngle : CGFloat {
		if  let  zone = widgetZone, !isCenter,
			let index = zone.siblingIndex,
			let     c = zone.parentZone?.count {
			let count = CGFloat(max(0, c - 1))
			let delta = CGFloat(index) - (count / 2.0)
			let     o = delta * incrementAngle

			return  o
		}

		return k2PI
	}

	var circlesHighlightFrame : CGRect {
		let center = absoluteFrame.center
		let radius = gCircularModeRadius + 3.0
		let   rect = CGRect(origin: center, size: .zero).insetEquallyBy(-radius)

		return rect
	}

	// MARK: - static methods
	// MARK: -

	static func placesCount(at iLevel: Int) -> Int {
		let factor = iLevel == 2 ? 2 : 1
		var  level = iLevel
		var  total = 1

		while true {
			let cCount = maxVisibleChildren(at: level)
			level     -= 1

			if  cCount > 0 {
				total *= cCount
			}

			if  level  < 0 {
				total *= factor

				return total
			}
		}
	}

	static func maxVisibleChildren(at level: Int) -> Int {
		let   children = visibleChildren(at: level - 1)
		var maxVisible = 0

		for child in children {
			if  let  count = child.widgetZone?.visibleChildren.count,
				maxVisible < count {
				maxVisible = count
			}
		}

		return maxVisible
	}

	static func traverseAllVisibleWidgetsByLevel(_ block: IntZoneWidgetsClosure) {
		var   level = 0
		var widgets = visibleChildren(at: level)

		while widgets.count != 0 {
			block(level, widgets)

			level  += 1
			widgets = visibleChildren(at: level)
		}
	}

	static func visibleChildren(at level: Int) -> ZoneWidgetArray {
		var widgets = ZoneWidgetArray()

		for widget in gHere.visibleWidgets {
			if  widget.linesLevel == level {
				widgets.append(widget)
			}
		}

		return widgets
	}

	static func ringRadius(at level: Int) -> CGFloat {
		let    thrice = gCircularModeRadius * 2.5
		let increment = gDotWidth + thrice + gDotHeight
		let     start = gDotWidth / 2.0

		return  start + (CGFloat(level) * increment)
	}

	// MARK: - update
	// MARK: -

	func circlesUpdateWidgetDrawnSize() {
		if  let  size = textWidget?.frame.size {
			drawnSize = size.insetBy(gDotHeight, gDotHeight)
		}
	}

	func updateTextViewFrame(_ absolute: Bool = false) {
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

	func updateAllDotFrames(_ absolute: Bool) {
		if  absolute {
			for line in childrenLines {
				line.circlesUpdateDotFrames(relativeTo: absoluteFrame, hideDragDot: hideDragDot)
			}
		}
	}

	// MARK: - traverse
	// MARK: -

	func updateTextAndDotFrames(_ absolute: Bool = false) {
		updateTextViewFrame(absolute)
		updateAllDotFrames (absolute)
	}

	func updateByLevelAllFrames(in controller: ZMapController?, _ absolute: Bool = false) {
		ZoneWidget.traverseAllVisibleWidgetsByLevel { (    level, widgets) in
			widgets.updateAllWidgetFrames             (at: level, in: controller, absolute)
		}

		traverseAllWidgetProgeny(inReverse: !absolute) { iWidget in
			iWidget.updateTextAndDotFrames  (absolute)  // sets lineAngle
		}
	}

	func circlesGrandUpdate() {
		updateByLevelAllFrames(in: controller)
		updateFrameSize()
		updateByLevelAllFrames(in: controller, true)
		updateAbsoluteFrame(relativeTo: controller)
	}

}

// MARK: - widgets array
// MARK: -

extension ZoneWidgetArray {

	var scrollOffset : CGPoint { return CGPoint(x: -gScrollOffset.x, y: gScrollOffset.y + 21) }

	func updateAllWidgetFrames(at  level: Int, in controller: ZMapController?, _ absolute: Bool = false) {
		if  let center = controller?.mapPseudoView?.frame.center {
			let   half = gCircularModeRadius
			let offset = scrollOffset
			let radius = ZoneWidget.ringRadius(at: level)

			for w in self {
				if  absolute {
					w.updateAbsoluteFrame(relativeTo: controller)
				} else if w.linesLevel > 0 {
					let   angle = Double(w.placeAngle)
					let rotated = CGPoint(x: .zero, y: radius).rotate(by: angle)
					let  origin = center + rotated - offset
					let    rect = CGRect(origin: origin, size:     .zero).expandedEquallyBy(half)
					w   .bounds = CGRect(origin:  .zero, size: rect.size)
					w    .frame = rect

//					print(" w \(widget.linesLevel) \(angle.stringTo(precision: 1)) \(widget)")
				}
			}
		}
	}

}

// MARK: - line
// MARK: -

extension ZoneLine {

	var lineAngle : CGFloat {
		if  let angle = parentToChildLine?.angle {
			return angle
		}

		return .zero
	}

	var parentToChildLine : CGPoint? {
		if  let pCenter = parentWidget?.frame.center,
			let cCenter =  childWidget?.frame.center {
			let    cToC = cCenter - pCenter

			return cToC
		}

		return nil
	}

	var circlesLineRect : CGRect {
		return .zero // TODO: compute this
	}

	var circlesAbsoluteDropDotRect: CGRect {
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

	func circlesUpdateDotFrames(relativeTo absoluteTextFrame: CGRect, hideDragDot: Bool) {
		dragDot?  .circlesUpdateDotAbsoluteFrame(relativeTo: absoluteTextFrame)
		revealDot?.circlesUpdateDotAbsoluteFrame(relativeTo: absoluteTextFrame)
	}

	func circlesStraightLinePath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
		let   path = ZBezierPath()
		let  start = iRect.origin
		let radius = iRect.size.hypotenuse
		let    end = CGPoint(x: .zero, y: radius).rotate(by: Double(lineAngle)).offsetBy(start)
		let   clip = CGRect(start: start, extent: end).expandedEquallyBy(10.0)

		path.move(to: start)
		path.line(to: end)

		if  gDebugDraw {
			clip.drawColoredRect(.green)
		}

		return path
	}

	func circlesUpdateLineSize() {
		// TODO: use radius to create point (vector)
		// use angle to rotate
		// use this to create drawnSize
	}

}

// MARK: - dot
// MARK: -

extension ZoneDot {

	// reveal dot is at circle around text, at angle, drag dot is further out along same ray

	func circlesUpdateDotAbsoluteFrame(relativeTo absoluteTextFrame: CGRect) {

		// line's length determined by parentToChildLine

		if  let         l = line,
			let    center = l.parentWidget?.frame.center,
			let      cToC = l.parentToChildLine {
			let    length = cToC.length
			let     width = isReveal ? gDotHeight : gDotWidth
			let      size = CGSize(width: width, height: gDotWidth)
			let    radius = gCircularModeRadius + (width / 1.5) + 1.5
			let   divisor = isReveal ? radius : (length - radius)
			let     ratio = divisor / length
			let    offset = cToC * ratio
			let    origin = center + offset - size
			l     .length = radius
			absoluteFrame = CGRect(origin: origin, size: drawnSize)

			updateTooltips()
		}
	}

	func circlesDrawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
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
