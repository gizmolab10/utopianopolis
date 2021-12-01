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

	func circularModeUpdateSize() {
		if  let  size = textWidget?.frame.size {
			drawnSize = size.insetBy(gDotHeight, gDotHeight)
		}
	}

	func specificAngles(for zone: Zone) -> (Double, Double, Double) {

		// use line level, if 0, puff ball spread
		// else if children count is 4 or less,
		// narrow fan spread, else puff ball spread
		// TODO: puff balls have longer radius
		// longer yet if immediate siblings are both puff balls

		let         pi = Double.pi
		let      count = Double(zone.count)
		var      start = Double(parentLine?.angle ?? 0.0)
		var     offset = 1.0
		var     spread = pi * 2.0
		let  increment = pi / 6.0
		let   isCenter = linesLevel == 0
		showAsPuffy    = (count > 6.0 || isCenter) && hasVisibleChildren

		if !isCenter {
			if  showAsPuffy {
				offset = 0.5
				spread = pi * 1.5
				parentLine?.length = 125.0
			} else {
				offset = 1.5
				spread = increment * count
				start += increment
			}

			start += spread / 2.0
		}

		return (start, spread, offset)
	}

	func circularModeUpdateChildrenVectors(_ absolute: Bool = false) {
		if  let                    zone = widgetZone {
			let (start, spread, offset) = specificAngles(for: zone)
			let                  angles = anglesArray(childrenLines.count, startAngle: start, spreadAngle: spread, offset: offset, clockwise: true)

			if  angles.count > 0 {
				halfAngle               = angles[0] / 2.0

				for (index, child) in childrenLines.enumerated() {
					child        .angle = CGFloat(angles[index])
				}
			}
		}
	}

	func circularModeUpdateChildrenViewDrawnSize() {
		childrenView?.drawnSize = .zero // CGSize.squared(200.0)
	}

	func circularModeUpdateChildrenLinesDrawnSize() {
		linesView?.drawnSize = .zero // CGSize.squared(200.0)
	}

	func circularModeUpdateChildrenWidgetFrames(_ absolute: Bool = false) {
		if  hasVisibleChildren {
			var     index = childrenWidgets.count
			while   index > 0 {
				index    -= 1 // go backwards [up] the children array
				let child = childrenWidgets[index]

				if  absolute {
					child.updateAbsoluteFrame(toController: controller)
				} else if  let t = pseudoTextWidget,
						   let w = child.pseudoTextWidget?.frame.size.width {
					if  gOtherCircularAlgorithm {
						let     line = childrenLines[index]
						let    angle = Double(line.angle)
						let     half = w / 2.0
						let   radius = ringRadius + gDotHeight + line.length + gDotWidth
						let   center = t.frame.center
						let     size = CGSize.squared(w)
						let  rotated = CGPoint(x: radius, y: 0.0).rotate(by: angle)
						child.offset = CGPoint(x:   half, y: 0.0).rotate(by: angle)
						let   origin = center + rotated + child.offset
						let     rect = CGRect(origin: origin, size: size)
						child .frame = rect
					} else {
						let     line = childrenLines[index]
						let    angle = Double(line.angle)
						let     half = w / 2.0
						let   radius = ringRadius + gDotHeight + line.length + gDotWidth + half - 7.0
						let   center = t.frame.extent + CGPoint(x: -10.0, y: half - 10.0)
						let     size = CGSize.squared(w)
						let  rotated = CGPoint(x: radius, y: 0.0).rotate(by: angle)
						child.offset = CGPoint.equaled(half)
						let   origin = center + rotated - child.offset
						let     rect = CGRect(origin: origin, size: size)
						child .frame = rect
					}
				}
			}
		}
	}

	func circularModeUpdateTextViewFrame(_ absolute: Bool = false) {
		if  let                 t = pseudoTextWidget {
			if  absolute {
				t.updateAbsoluteFrame(toController: controller)

				textWidget?.frame = t.absoluteFrame
			} else if let    size = textWidget?.drawnSize {
				ringRadius        = size.width / 2.0 + gDotWidth
				let        origin = CGPoint(x: -30.0, y: -10.0)
				let          rect = CGRect(origin: origin, size: size)
				t          .frame = rect
			}
		}
	}

	var circularModeHighlightFrame : CGRect {
		if  let      frame = pseudoTextWidget?.absoluteFrame {
			let     center = frame.center
			let     radius = frame.size.width / 2.0 + 3.0
			let       rect = CGRect(origin: center, size: .zero).insetEquallyBy(-radius)
			return rect
		}

		return.zero
	}

	var circularModeSelectionHighlightPath: ZBezierPath {
		return ZBezierPath(ovalIn: highlightFrame)
	}

	func circularModeUpdateDotFrames(_ absolute: Bool) {
		if  absolute,
			let textFrame = pseudoTextWidget?.absoluteFrame {

			for line in childrenLines {
				line.circularModeUpdateDotFrames(relativeTo: textFrame, hideDragDot: hideDragDot)
			}
		}
	}

	func circularModeUpdateAllFrames(_ absolute: Bool) {
		updateAllChildrenVectors(absolute)   // needed for updating text view frames
		traverseAllWidgetProgeny(inReverse: !absolute) { iWidget in
			iWidget.circularModeUpdateSubframes(absolute)
		}
	}

	func circularModeUpdateSubframes(_ absolute: Bool) {
		circularModeUpdateTextViewFrame       (absolute)
		circularModeUpdateChildrenWidgetFrames(absolute)
		circularModeUpdateDotFrames           (absolute)
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
		if !hideDragDot {
			dragDot?.circularModeUpdateAbsoluteFrame(relativeTo: absoluteTextFrame)
		}

		revealDot?  .circularModeUpdateAbsoluteFrame(relativeTo: absoluteTextFrame)
	}

	func circularModeStraightLinePath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
		let radius = iRect.size.hypotenuse
		let  start = angle.upward ? iRect.origin : iRect.topLeft
		let    end = CGPoint(x: radius, y: CGFloat(0.0)).rotate(by: Double(angle)).offsetBy(start)
		let   path = ZBezierPath()

//		if  gDebugDraw {
//			let  r = CGRect(start: start, extent: end)
//			r.drawColoredRect(.blue)
//		}

		path.move(to: start)
		path.line(to: end)

		return path
	}

	func circularModeUpdateSize() {
		// TODO: use radius to create point (vector)
		// use angle to rotate
		// use this to create drawnSize
	}

}

// MARK:- dot
// MARK:-

extension ZoneDot {

	// reveal dot is at circle around text, at angle, drag dot is further out along same ray

	func circularModeUpdateAbsoluteFrame(relativeTo absoluteTextFrame: CGRect) {
		if  let         l = line,
			let         r = l.parentWidget?.ringRadius {

			// length of vector = ringRadius
			// longer for drag dot: add line length and dot width
			// rotate to angle (around zero point)
			// move zero point to text center
			// move further by size of dot

			let     angle = Double(l.angle)
			let     width = isReveal ? gDotHeight : gDotWidth
			let    length = isReveal ? 0.0 : l.length + gDotWidth
			let   rotated = CGPoint(x: r + length, y: 0.0).rotate(by: angle)
			let      size = CGSize(width: width, height: gDotWidth)
			let    center = absoluteTextFrame.center
			let    origin = center + rotated - size
			absoluteFrame = CGRect(origin: origin, size: drawnSize)

			updateTooltips()
		}
	}

	func circularModeDrawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
		let     angle = line?.angle ?? 0.0
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
//
//		if !isReveal {
//			iDirtyRect.insetEquallyBy(3.0).drawColoredCircle(.red)
//		}
	}

}
