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
			let   dSize = revealDot?.drawnSize {
			var   width = childrenView?.drawnSize.width  ?? 0.0
			var  height = childrenView?.drawnSize.height ?? 0.0
			let   extra = width != 0.0 ? 0.0 : gGenericOffset.width / 2.0
			width      += t.drawnSize.width
			let dheight = dSize.height
			let dWidth  = dSize.width * 2.0
			width      += dWidth + extra - (hideDragDot ? 5.0 : 4.0)

			if  height  < dheight {
				height  = dheight
			}

			drawnSize   = CGSize(width: width, height: height)
		}
	}

	func circularUpdateHitRect(_ absolute: Bool = false) {
		if  absolute,
			let              t = textWidget,
			let            dot = revealDot {
			let revealDotDelta = dot.isVisible ? CGFloat(0.0) : dot.drawnSize.width - 6.0    // expand around reveal dot, only if it is visible
			let            gap = gGenericOffset.height
			let       gapInset =  gap         /  8.0
			let     widthInset = (gap + 32.0) / -2.0
			let    widthExpand = (gap + 24.0) /  6.0
			var           rect = t.frame.insetBy(dx: (widthInset - gapInset - 2.0) * ratio, dy: -gapInset)               // get size from text widget
			rect.size .height += (kHighlightHeightOffset + 2.0) / ratio
			rect.size  .width += (widthExpand - revealDotDelta) / ratio
			highlightFrame     = rect
		}
	}

	func circularUpdateChildrenAngles() {

	}

	func circularUpdateChildrenFrames(_ absolute: Bool = false) {
		if  hasVisibleChildren {
			var    height = CGFloat.zero
			var     index = childrenWidgets.count
			let    angles = anglesArray(index, startAngle: 0.0, oneSet: true, isFat: false, clockwise: true)
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
					child .parentAngle = CGFloat(angles[index])
					child.parentRadius = 25.0
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

	var circularAbsoluteDropDotRect: CGRect {
		var rect = CGRect()

		if  let zone = widgetZone {
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

				if  let       firstDot = dot(at: firstindex) {
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

					} else if lastIndex < zone.count, let secondDot = dot(at: lastIndex) {

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

	func circularLineKind(for delta: CGFloat) -> ZLineKind {
		let threshold = 2.0   * kVerticalWeight
		let  adjusted = delta * kVerticalWeight

		if adjusted > threshold {
			return .above
		} else if adjusted < -threshold {
			return .below
		}

		return .straight
	}

	func circularLineKind(to dragRect: CGRect) -> ZLineKind? {
		let toggleRect = revealDot?.absoluteActualFrame ?? .zero
		let      delta = dragRect.midY - toggleRect.midY

		return lineKind(for: delta)
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

		if  let z = widgetZone, gDebugDraw { // for debugging hover
			print("drawing \(isReveal ? "REVEAL" : "DRAG  ") dot for \"\(z)\"\(parameters.filled ? " FILLED" : "")\(isHovering ? " HOVER" : "")")
		}

		path.lineWidth = thickness
		path .flatness = 0.0001

		path.stroke()
		path.fill()
	}

}
