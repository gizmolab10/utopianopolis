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

	func circularUpdateSize() {
		if  let       t = textWidget,
			let   lSize = linesView?.drawnSize {
			let   cSize = childrenView?.drawnSize
			var   width = cSize?.width  ?? 0.0
			var  height = cSize?.height ?? 0.0
			let   extra = width != 0.0 ? 0.0 : gGenericOffset.width / 2.0
			width      += t.drawnSize.width
			let lheight = lSize.height
			let  lWidth = lSize.width * 2.0
			width      += lWidth + extra - (hideDragDot ? 5.0 : 4.0)

			if  height  < lheight {
				height  = lheight
			}

			drawnSize   = CGSize(width: width, height: height)
		}
	}

	func circularUpdateChildrenVectors(_ absolute: Bool = false) {
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

			if  absolute {
				ringRadius      = 40.0
			} else {
				var spreadAngle = Double.pi * 2.0
				let  startAngle = Double(parentLine?.angle ?? 0.0)

				if !isPuffBall {
					spreadAngle = spreadAngle * Double(count) / 16.0
				}

				let      angles = anglesArray(count, startAngle: startAngle, spreadAngle: spreadAngle, oneSet: true, isFat: false, clockwise: true)

				for (index, child) in childrenLines.enumerated() {
					child.angle = CGFloat(angles[index])
				}
			}
		}
	}

	func circularUpdateChildrenViewDrawnSize() {
		// children view drawn size is used
	}

	func circularUpdateChildrenFrames(_ absolute: Bool = false) {
		if  hasVisibleChildren {
			var     index = childrenWidgets.count
			while   index > 0 {
				index    -= 1 // go backwards [up] the children array
				let child = childrenWidgets[index]

				if  absolute {
					child.updateAbsoluteFrame(toController: controller)
				} else {
					let    line = childrenLines[index]
					let    size = child.drawnSize
					let   angle = line.angle
					let  radius = ringRadius
					let  origin = CGPoint(x: radius, y: 0.0).rotate(by: Double(angle))
					let    rect = CGRect(origin: origin, size: size)
					child.frame = rect
				}
			}
		}
	}

	func circularUpdateTextViewFrame(_ absolute: Bool = false) {
		if  let                 p = pseudoTextWidget {
			if  absolute {
				p.updateAbsoluteFrame(toController: controller)

				textWidget?.frame = p.absoluteFrame
			} else if let    size = textWidget?.drawnSize {
				let             x = hideDragDot ? 20.0 : gGenericOffset.width + 4.0
				let             y = (drawnSize.height - size.height) / 2.0
				let        origin = CGPoint(x: x, y: y)
				p          .frame = CGRect(origin: origin, size: size)
			}
		}
	}

	func circularUpdateChildrenViewFrame(_ absolute: Bool = false) {
		if  hasVisibleChildren, let c = childrenView {
			if  absolute {
				c.updateAbsoluteFrame(toController: controller)
			} else if let textFrame = pseudoTextWidget?.frame {
				let           ratio = type.isBigMap ? 1.0 : kSmallMapReduction / 3.0
				let               x = textFrame.maxX + (CGFloat(gChildrenViewOffset) * ratio)
				let          origin = CGPoint(x: x, y: CGFloat.zero)
				let   childrenFrame = CGRect(origin: origin, size: c.drawnSize)
				c            .frame = childrenFrame
			}
		}
	}

	func circularDrawSelectionHighlight(_ dashes: Bool, _ thin: Bool) {
		let        rect = highlightFrame
		if rect.isEmpty { return }
		let      radius = rect.minimumDimension / 2.08 - 1.0
		let       color = widgetZone?.color
		let strokeColor = color?.withAlphaComponent(0.30)
		let        path = ZBezierPath(roundedRect: rect, cornerRadius: radius)
		path .lineWidth = CGFloat(gDotWidth) / 3.5
		path  .flatness = 0.0001

		if  dashes || thin {
			path.addDashes()

			if  thin {
				path.lineWidth = CGFloat(1.5)
			}
		}

		strokeColor?.setStroke()
		path.stroke()
	}

}

// MARK:- line
// MARK:-

extension ZoneLine {

	var circularLineRect : CGRect {
		return .zero // TODO
	}

	var circularAbsoluteDropDotRect: CGRect {
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

	func circularStraightPath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
		let  angle = angle
		let radius = iRect.size.length
		let  start = angle.upward ? iRect.origin : iRect.topLeft
		let    end = CGPoint(x: radius, y: CGFloat(0.0)).rotate(by: Double(angle)).offsetBy(start)
		let   path = ZBezierPath()

		path.move(to: start)
		path.line(to: end)

		return path
	}

	func circularUpdateSize() {
		// TODO: use radius to create point (vector)
		// use angle to rotate
		// use this to create drawnSize
	}

}

// MARK:- dot
// MARK:-

extension ZoneDot {

	// reveal dot is at circle around text, at angle, drag dot is further out along same ray

	func circularUpdateAbsoluteFrame(relativeTo absoluteTextFrame: CGRect) {
		if  let         l = line,
			let         w = l.parentWidget {
			let     angle = l.angle
			let    radius = w.ringRadius + (isReveal ? 0.0 : 25.0)
			let    origin = CGPoint(x: radius, y: 0.0).rotate(by: Double(angle)).offsetBy(absoluteTextFrame.center)
			absoluteFrame = CGRect(origin: origin, size: drawnSize)
		}
	}

	func circularDrawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
		let     angle = line?.angle ?? 0.0
		let thickness = CGFloat(gLineThickness) * 2.0
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
