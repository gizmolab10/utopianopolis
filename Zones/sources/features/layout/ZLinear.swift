//
//  ZLinear.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/11/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

// MARK: - widget
// MARK: -

extension ZoneWidget {

	func linesUpdateWidgetDrawnSize() {
		if  let       t = textWidget,
			let   lSize = linesView?   .drawnSize {
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

	func linesUpdateChildrenViewDrawnSize() {
		var  childrenSize = CGSize.zero

		if  hasVisibleChildren {
			var    height = CGFloat.zero
			var     width = CGFloat.zero
			var     index = childrenWidgets.count
			while   index > 0 {
				index    -= 1 // go backwards [up] the children array
				let child = childrenWidgets[index]
				let  size = child.drawnSize
				height   += size.height

				if  width < size.width {
					width = size.width
				}
			}

			childrenSize  = CGSize(width: width, height: height)
		}

		childrenView?    .drawnSize = childrenSize
		childrenView?.absoluteFrame = .zero
		childrenView?        .frame = .zero
		linesView?   .absoluteFrame = .zero
		linesView?           .frame = .zero
	}

	func linesUpdateChildrenLinesDrawnSize() {
		var     width = CGFloat(0.0)
		var    height = CGFloat(0.0)

		for line in childrenLines {
			line.updateLineSize()

			let  size = line.drawnSize
			height   += size.height
			if  width < size.width {
				width = size.width
			}
		}

		linesView?.drawnSize = CGSize(width: width, height: height)
	}

	func linesUpdateChildrenWidgetFrames(_ absolute: Bool = false) {
		if  hasVisibleChildren {
			var    height = CGFloat.zero
			var     index = childrenWidgets.count
			while   index > 0 {
				index    -= 1 // go backwards [up] the children array
				let child = childrenWidgets[index]

				if  absolute {
					child.updateAbsoluteFrame(relativeTo: controller)
				} else {
					let    size = child.drawnSize
					let  origin = CGPoint(x: .zero, y: height)
					height     += size.height
					let    rect = CGRect(origin: origin, size: size)
					child.frame = rect
				}
			}
		}
	}

	func linesUpdateTextViewFrame(_ absolute: Bool = false) {
		if  let                 t = pseudoTextWidget {
			if  absolute {
				t.updateAbsoluteFrame(relativeTo: controller)

				textWidget?.frame = t.absoluteFrame
			} else if let    size = textWidget?.drawnSize {
				let             x = hideDragDot ? 20.0 : gGenericOffset.width + 4.0
				let             y = (drawnSize.height - size.height) / 2.0
				let        origin = CGPoint(x: x, y: y)
				t          .frame = CGRect(origin: origin, size: size)
			}
		}
	}

	func linesUpdateChildrenViewFrame(_ absolute: Bool = false) {
		if  hasVisibleChildren, let c = childrenView {
			if  absolute {
				c.updateAbsoluteFrame(relativeTo: controller)
			} else if let textFrame = pseudoTextWidget?.frame {
				let           ratio = type.isBigMap ? 1.0 : kSmallMapReduction / 3.0
				let               x = textFrame.maxX + (CGFloat(gChildrenViewOffset) * ratio)
				let          origin = CGPoint(x: x, y: CGFloat.zero)
				let   childrenFrame = CGRect(origin: origin, size: c.drawnSize)
				c            .frame = childrenFrame
			}
		}
	}

	func linesUpdateLinesViewFrame(_ absolute: Bool = false) {

	}

	var linesHighlightFrame : CGRect {
		if  let              t = textWidget,
			let            dot = childrenLines.first?.revealDot {
			let revealDotDelta = dot.dotIsVisible ? CGFloat(0.0) : dot.drawnSize.width - 6.0    // expand around reveal dot, only if it is visible
			let            gap = gGenericOffset.height
			let       gapInset =  gap         /  8.0
			let     widthInset = (gap + 32.0) / -2.0
			let    widthExpand = (gap + 24.0) /  6.0
			var           rect = t.frame.insetBy(dx: (widthInset - gapInset - 2.0) * ratio, dy: -gapInset)               // get size from text widget
			rect.size .height += (kHighlightHeightOffset + 2.0) / ratio
			rect.size  .width += (widthExpand - revealDotDelta) / ratio

			return rect
		}

		return .zero
	}

	var linesSelectionHighlightPath: ZBezierPath {
		let   rect = highlightFrame
		let radius = rect.minimumDimension / 2.08 - 1.0
		let   path = ZBezierPath(roundedRect: rect, cornerRadius: radius)

		return path
	}

	func linesUpdateDotFrames(_ absolute: Bool) {
		if  absolute,
			let textFrame = pseudoTextWidget?.absoluteFrame {

			if !hideDragDot {
				parentLine?.dragDot?.linesUpdateAbsoluteFrame(relativeTo: textFrame)
			}

			for line in childrenLines {
				line     .revealDot?.linesUpdateAbsoluteFrame(relativeTo: textFrame)
			}
		}
	}

	// this is called twice in grand update
	// first with absolute false, then with true

	func linesUpdateAllFrames(_ absolute: Bool = false) {
		traverseAllWidgetProgeny(inReverse: !absolute) { iWidget in
			iWidget.linesUpdateSubframes(absolute)
		}
	}

	func linesUpdateSubframes(_ absolute: Bool = false) {
		linesUpdateTextViewFrame       (absolute)
		linesUpdateChildrenWidgetFrames(absolute)
		linesUpdateDotFrames           (absolute)
		linesUpdateChildrenViewFrame   (absolute)
		linesUpdateLinesViewFrame      (absolute)
	}

	func linesGrandUpdate() {
		linesUpdateAllFrames()
		updateFrameSize()
		linesUpdateAllFrames(true)
		updateAbsoluteFrame(relativeTo: controller)
	}

}

// MARK: - line
// MARK: -

extension ZoneLine {

	var linesLineRect : CGRect {
		return .zero
	}

	var linesAbsoluteDropDotRect: CGRect {
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

	func linesStraightLinePath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
		let rect = iRect.centeredHorizontalLine(thick: CGFloat(gLineThickness))
		let path = ZBezierPath(rect: rect)

		path.setClip()

		return path
	}

	func linesLineKind(for delta: CGFloat) -> ZLineCurve {
		let   threshold =  CGFloat(2.0)
		if        delta >  threshold {
			return .above
		} else if delta < -threshold {
			return .below
		}

		return .straight
	}

	func linesLineKind(to targetRect: CGRect) -> ZLineCurve? {
		let toggleRect = revealDot?.absoluteActualFrame ?? .zero
		let      delta = targetRect.midY - toggleRect.midY

		return linesLineKind(for: delta)
	}

	func linesUpdateLineSize() {
		// all lines have at least a reveal dot
		drawnSize = revealDot?.updateDotDrawnSize() ?? .zero
	}

}

// MARK: - dot
// MARK: -

extension ZoneDot {

	func linesUpdateAbsoluteFrame(relativeTo absoluteTextFrame: CGRect) {
		let         x = CGPoint(drawnSize).x
		let    origin = isReveal ? absoluteTextFrame.bottomRight : absoluteTextFrame.origin.offsetBy(-x, 0.0)
		absoluteFrame = CGRect(origin: origin, size: drawnSize)

		updateTooltips()
	}

	func linesDrawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
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

extension ZMapController {
	
	func linesDetectWidget(at location: CGPoint) -> ZoneWidget? {
		if  let widgets = gWidgets.allWidgets(for: widgetType) {
			for widget in widgets.reversed() {
				if  widget.highlightFrame.contains(location) {
					return widget
				}
			}
		}
		
		return nil
	}
	
}
