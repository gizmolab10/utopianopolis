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

	func circularModeUpdateChildrenVectors(_ absolute: Bool = false) {
		// TODO: use line level, if 0, puff ball spread
		// else if children count is 4 or less, narrow fan spread, else puff ball spread
		// puff balls have longer radius
		// longer yet if immediate siblings are both puff balls

		if  let        zone = widgetZone, hasVisibleChildren {
			let       count = zone.count
			var isPuffBall  = true
			if  linesLevel != 0,
				count       < 5 {
				isPuffBall  = false
			}

			if !absolute {
				var spreadAngle = Double.pi * 2.0
				let  startAngle = Double(parentLine?.angle ?? 0.0)

				if !isPuffBall {
					spreadAngle = spreadAngle * Double(count) / 16.0
				}

				let      angles = anglesArray(count, startAngle: startAngle, spreadAngle: spreadAngle, oneSet: true, isFat: false, clockwise: true)

				for (index, child) in childrenLines.enumerated() {
					child.angle = CGFloat(angles[index])
				}
			} else if  let    w = textWidget?.frame.width {
				ringRadius      = w / 2.0 + gDotWidth
			}
		}
	}

	func circularModeUpdateChildrenViewDrawnSize() {
		childrenView?.drawnSize = CGSize(width: 100.0, height: 100.0)
	}

	func circularModeUpdateChildrenLinesDrawnSize() {
		linesView?   .drawnSize = CGSize(width: 100.0, height: 100.0)
	}

	func updateFrame(of view: ZPseudoView?, _ absolute: Bool = false) {
		if  let v = view, hasVisibleChildren {
			if  absolute {
				v.updateAbsoluteFrame(toController: controller)
			} else  {
				let size   = v.drawnSize
				let origin = CGPoint(size.multiplyBy(-0.5))
				v.frame    = CGRect(origin: origin, size: size)
			}
		}
	}

	func circularModeUpdateLinesViewFrame   (_ absolute: Bool = false) { updateFrame(of:    linesView, absolute)}
	func circularModeUpdateChildrenViewFrame(_ absolute: Bool = false) { updateFrame(of: childrenView, absolute)}

	func circularModeUpdateChildrenWidgetFrames(_ absolute: Bool = false) {
		if  hasVisibleChildren {
			var     index = childrenWidgets.count
			while   index > 0 {
				index    -= 1 // go backwards [up] the children array
				let child = childrenWidgets[index]

				if  absolute {
					child.updateAbsoluteFrame(toController: controller)
				} else {
					let    line = childrenLines[index]
					let   angle = Double(line.angle)
					let    size = child.drawnSize               .rotate(by: angle)
					let  origin = CGPoint(x: ringRadius, y: 0.0).rotate(by: angle)
					let    rect = CGRect(origin: origin, size: size)
					child.frame = rect
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
				let        origin = CGPoint(x: -30.0, y: -10.0)
				t          .frame = CGRect(origin: origin, size: size)
			}
		}
	}

	func circularModeUpdateHighlightFrame(_ absolute: Bool = false) {
		if  absolute,
			let          t = pseudoTextWidget {
			let      frame = t.absoluteFrame
			let     center = frame.center
			let     radius = frame.size.width / 2.0 + 3.0
			let       rect = CGRect(origin: center, size: .zero).insetEquallyBy(-radius)
			highlightFrame = rect
		}
	}

	var circularModeSelectionHighlightPath: ZBezierPath {
		return ZBezierPath(ovalIn: highlightFrame)
	}

	func circularModeUpdateDotFrames(_ absolute: Bool) {
		if  absolute,
			let textFrame = pseudoTextWidget?.absoluteFrame {

			for line in childrenLines {
				line.updateDotFrames(relativeTo: textFrame, hideDragDot: hideDragDot)
			}
		}
	}

}

// MARK:- line
// MARK:-

extension ZoneLine {

	var circularModeLineRect : CGRect {
		return .zero // TODO
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

	func circularModeStraightLinePath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
		let  angle = angle
		let radius = iRect.size.length
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
			let    radius = r + (isReveal ? 0.0 : l.length)
			let    center = CGPoint(absoluteTextFrame.center - CGPoint(x: gDotHeight, y: gDotWidth))
			let   rotated = CGPoint(x: radius, y: 0.0).rotate(by: Double(l.angle))
			absoluteFrame = CGRect(origin: center + rotated, size: drawnSize)
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

//		if  let z = widgetZone, gDebugDraw { // for debugging hover
//			print("drawing \(isReveal ? "REVEAL" : "DRAG  ") dot for \"\(z)\"\(parameters.filled ? " FILLED" : "")\(isHovering ? " HOVER" : "")")
//		}

		path.lineWidth = thickness
		path .flatness = 0.0001

		path.stroke()
		path.fill()
	}

}
