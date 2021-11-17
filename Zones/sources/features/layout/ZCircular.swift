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

	func circularUpdateChildrenViewDrawnSize() {
		if !hasVisibleChildren {
			childrenView?.drawnSize = CGSize.zero
		} else {
			var         biggestSize = CGSize.zero
			var              height = CGFloat.zero

			for child in childrenWidgets {			// traverse progeny, updating their frames
				let            size = child.drawnSize
				height             += size.height

				if  size.width      > biggestSize.width {
					biggestSize     = size
				}
			}

			childrenView?.drawnSize = CGSize(width: biggestSize.width, height: height)
		}
	}

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
		// longest if immediate sibling(s) is a (are) puff ball(s)

		if  let            zone = widgetZone, hasVisibleChildren {
			let       count = zone.count
			var isPuffBall  = true
			if  linesLevel != 0,
				count       < 5 {
				isPuffBall  = false
			}
			if  absolute {
				// adjust radius
			} else {
				var spreadAngle = Double.pi * 2.0
				let  startAngle = Double(parentLine?.parentAngle ?? 0.0)
				if  isPuffBall {
					spreadAngle = spreadAngle * Double(count) / 16.0
				}

				let      angles = anglesArray(count, startAngle: startAngle, spreadAngle: spreadAngle, oneSet: true, isFat: false, clockwise: true)

				for (index, child) in childrenLines.enumerated() {
					child.parentAngle = CGFloat(angles[index])
				}
			}
		}
	}

	func angles(_ isPuffBall: Bool) -> [CGFloat] {
		// TODO: assume parent angle is already set, add it to all the angles
		return [0.0]
	}

	func circularUpdateChildrenFrames(_ absolute: Bool = false) {
		if  hasVisibleChildren {
			var    height = CGFloat.zero
			var     index = childrenWidgets.count
			while   index > 0 {
				index    -= 1 // go backwards [up] the children array
				let child = childrenWidgets[index]

				if  absolute {
					child.updateAbsoluteFrame(toController: controller)
				} else {
					let           size = child.drawnSize
					let         origin = CGPoint(x: .zero, y: height)
					height            += size.height
					let           rect = CGRect(origin: origin, size: size)
					child       .frame = rect
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

	func circularUpdateSize() {
		// TODO: use radius to create point (vector)
		// use angle to rotate
		// use this to create drawnSize
	}

	func circularUpdateFrame(relativeTo textFrame: CGRect) {
		// TODO: use center of drag dot's rect for origin
	}

}

// MARK:- dot
// MARK:-

extension ZoneDot {

	func circularUpdateFrame(relativeTo textFrame: CGRect) {
		let         x = CGPoint(drawnSize).x
		let    origin = isReveal ? textFrame.bottomRight : textFrame.origin.offsetBy(-x, 0.0)
		absoluteFrame = CGRect(origin: origin, size: drawnSize)

		updateTooltips()
	}

	func circularDrawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
		let  thickness = CGFloat(gLineThickness) * 2.0
		var       path = ZBezierPath()

		if  parameters.isReveal {
			path       = ZBezierPath.bloatedTrianglePath(in: iDirtyRect, aimedRight: parameters.showList)
		} else {
			path       = ZBezierPath(ovalIn: iDirtyRect.insetEquallyBy(thickness))
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
