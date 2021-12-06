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

func gCircularModeVisibleChildren(at level: Int) -> ZoneWidgetArray {
	var widgets = ZoneWidgetArray()

	for widget in gHere.visibleWidgets {
		if  widget.linesLevel == level {
			widgets.append(widget)
		}
	}

	return widgets
}

func gCircularModeRingRadius(at level: Int) -> CGFloat { return CGFloat(level) * 200.0 }

extension ZoneWidget {

	var circularModeSpreadAngle: CGFloat {
		let  zCount = widgetZone?.count ?? 1
		let widgets = gCircularModeVisibleChildren(at: linesLevel)
		let  wCount = widgets.count

		return CGFloat(Double.pi * 2.0) * CGFloat(zCount) / CGFloat(wCount)
	}

	func circularModeUpdateWidgetSize() {
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
		var      start = Double(parentLine?.angle ?? 0.0) + (pi / 2.0)
		var     offset = 1.0
		var     spread = pi * 2.0
		let  increment = pi / 6.0
		let   isCenter = linesLevel == 0

		if !isCenter {
			offset = 1.5
			spread = increment * count
			start += increment - spread / 2.0
		}

		return (start, spread, offset)
	}

	func circularModeUpdateChildrenVectors(_ absolute: Bool = false) {
		if  let                    zone = widgetZone {
			let (start, spread, offset) = specificAngles(for: zone)
			let                  angles = anglesArray(childrenLines.count, startAngle: start, spreadAngle: spread, offset: offset, clockwise: true)

			if  angles.count > 0 {
				for (index, child) in childrenLines.enumerated() {
					child        .angle = CGFloat(angles[index])
				}
			}
		}
	}

	func circularModeUpdateChildrenWidgetFrames(_ absolute: Bool = false) {
		if  hasVisibleChildren {
			let    center = bounds.center
			let      half = kDefaultCircularModeRadius
			let    length = gDotHeight + (2.0 * (half + gDotWidth))
			var     index = childrenWidgets.count
			while   index > 0 {
				index    -= 1 // go backwards in the children array [up, counter-clockwise]
				let child = childrenWidgets[index]

				if  absolute {
					child.updateAbsoluteFrame(toController: controller)
				} else {
					let     line = childrenLines[index]
					let    angle = Double(line.angle)
					let   radius = length + line.length
					let  rotated = CGPoint(x: radius, y: .zero).rotate(by: angle)
					let   origin = center + rotated
					let     rect = CGRect(origin: origin, size:     .zero).expandedEquallyBy(half)
					child.bounds = CGRect(origin:  .zero, size: rect.size)
					child .frame = rect
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
				let          half = size.multiplyBy(0.5)
				let        origin = bounds.center
				let          rect = CGRect(origin: origin, size: .zero).expandedBy(half)
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
		if  absolute,
			let textFrame = pseudoTextWidget?.absoluteFrame {

			for line in childrenLines {
				line.circularModeUpdateDotFrames(relativeTo: textFrame, hideDragDot: hideDragDot)
			}
		}
	}

	// this is called twice in grand update
	// first with absolute false, then with true

	func circularModeUpdateAllFrames(_ absolute: Bool) {
		updateAllChildrenVectors(absolute)   // needed for updating text view frames
		traverseAllWidgetProgeny() { iWidget in
			iWidget.circularModeUpdateSubframes(absolute)
		}
	}

	func circularModeUpdateSubframes(_ absolute: Bool) {
		if  widgetZone != nil {
			circularModeUpdateChildrenWidgetFrames(absolute)
			circularModeUpdateTextViewFrame       (absolute)
			circularModeUpdateDotFrames           (absolute)
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
		let  start = angle.upward ? iRect.origin : iRect.topLeft
		let    end = CGPoint(x: radius, y: .zero).rotate(by: Double(angle)).offsetBy(start)
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
			let     angle = Double(l.angle)
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
	}

}
