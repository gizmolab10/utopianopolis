//
//  ZonesLine.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/26/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

class ZoneLine: ZPseudoView {

	var      dragDot : ZoneDot?
	var    revealDot : ZoneDot?
	var  childWidget : ZoneWidget?
	var parentWidget : ZoneWidget?
	var  angle = CGFloat.zero

	func addDots(sharedDot: ZoneDot?) {
		if  let p               = parentWidget {
			if  revealDot      == nil {
				revealDot       = sharedDot ?? ZoneDot(view: absoluteView)
				revealDot?.line = self

				addSubpseudoview(revealDot)
				revealDot?.setupForWidget(p, asReveal: true)
			}
		}

		if  let c         = childWidget, !c.hideDragDot,
			dragDot      == nil {
			dragDot       = ZoneDot(view: absoluteView)
			dragDot?.line = self

			addSubpseudoview(dragDot)
			dragDot?.setupForWidget(c, asReveal: false)
		}
	}

	var lineKind : ZLineKind {
		if  let     zone = parentWidget?.widgetZone,
			let      dot = dragDot,
			zone  .count > 1,
			let dragKind = lineKind(to: dot.absoluteActualFrame) {
			return dragKind
		}

		return .straight
	}

	func lineRect(to dragRect: CGRect) -> CGRect? {
		var rect: CGRect?

		if  let kind = lineKind(to: dragRect) {
			rect     = lineRect(to: dragRect, kind: kind)
		}

		return rect
	}

	func lineRect(to widget: ZoneWidget?, kind: ZLineKind) -> CGRect {
		if  let    dot = widget?.parentLine?.dragDot {
			let dFrame = dot.absoluteActualFrame

			return lineRect(to: dFrame, kind: kind)
		}

		return CGRect.zero
	}

	func linePath(in iRect: CGRect, kind: ZLineKind?, isDragLine: Bool) -> ZBezierPath {
		if  let    k = kind {
			switch k {
				case .straight: return straightPath(in: iRect, isDragLine)
				default:        return   curvedPath(in: iRect, kind: k)
			}
		}

		return ZBezierPath()
	}

	func updateHighlightRect(_ absolute: Bool = false) {
		if  absolute,
			let              p = parentWidget,
			let              t = p.textWidget,
			let            dot = revealDot {
			let revealDotDelta = dot.isVisible ? CGFloat(0.0) : dot.drawnSize.width - 6.0    // expand around reveal dot, only if it is visible
			let            gap = gGenericOffset.height
			let       gapInset =  gap         /  8.0
			let     widthInset = (gap + 32.0) / -2.0
			let    widthExpand = (gap + 24.0) /  6.0
			var           rect = t.frame.insetBy(dx: (widthInset - gapInset - 2.0) * p.ratio, dy: -gapInset)               // get size from text widget
			rect.size .height += (kHighlightHeightOffset + 2.0) / p.ratio
			rect.size  .width += (widthExpand - revealDotDelta) / p.ratio
			p.highlightFrame   = rect
		}
	}

	func drawLine() {
		if  let      child = childWidget,
			let       zone = child.widgetZone {
			let       kind = lineKind
			let       rect = lineRect(to: child, kind: kind)
			let       path = linePath(in:  rect, kind: kind, isDragLine: false)
			let      color = zone.color
			path.lineWidth = CGFloat(gLineThickness)

			if  kind != .straight {
				if  gDebugDraw {
					absoluteFrame.drawColoredRect(.blue)
				}
			}

			color?.setStroke()
			path.stroke()
		}
	}

	func drawDragLine(to dotRect: CGRect) {
		if  let       rect = lineRect(to: dotRect),
			let       kind = lineKind(to: dotRect) {
			let       path = linePath(in: rect, kind: kind, isDragLine: true)
			path.lineWidth = CGFloat(gLineThickness)

			path.stroke()
		}
	}

}
