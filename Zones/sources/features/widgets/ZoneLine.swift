//
//  ZonesLine.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/26/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

enum ZLineCurve: Int {
	case below    = -1
	case straight =  0
	case above    =  1
}

class ZoneLine: ZPseudoView {

	var             dragDot : ZoneDot?
	var           revealDot : ZoneDot?
	var         childWidget : ZoneWidget?
	var        parentWidget : ZoneWidget?
	var            isCenter : Bool            { return  parentWidget?.isCenter ?? true }
	override var controller : ZMapController? { return (parentWidget ?? childWidget)?.controller }
	var              length = CGFloat(25)

	var parentToChildLine : CGPoint? {
		if  let   pCenter = parentWidget?.frame.center,
			let   cCenter =  childWidget?.frame.center {
			let      cToC = cCenter - pCenter

			return cToC
		}

		return nil
	}

	var placeAngle : CGFloat {
		if  let p = parentWidget,
			let l = p.parentLine {
			return l.placeAngle + p.offsetAngle
		}

		return .zero
	}

	var lineAngle : CGFloat {
		if  isCenter {
			return placeAngle
		}

		if  let angle = parentWidget?.parentLine?.parentToChildLine?.angle {
			return angle
		}

		return .zero
	}

	func addDots(sharedRevealDot: ZoneDot?) {
		if  let p               = parentWidget {
			if  revealDot      == nil {
				revealDot       = sharedRevealDot ?? ZoneDot(view: absoluteView)
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

	var lineKind : ZLineCurve {
		if  isLinearMode,
			let     dot = dragDot,
			let    zone = parentWidget?.widgetZone, zone.count > 1,
			let    kind = lineKind(to: dot.absoluteActualFrame) {
			return kind
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

	func lineRect(to widget: ZoneWidget?, kind: ZLineCurve) -> CGRect {
		if  let    dot = widget?.parentLine?.dragDot {
			let dFrame = dot.absoluteActualFrame

			return lineRect(to: dFrame, kind: kind)
		}

		return CGRect.zero
	}

	func linePath(in iRect: CGRect, kind: ZLineCurve?, isDragLine: Bool = false) -> ZBezierPath {
		if  let    k = kind {
			switch k {
				case .straight: return straightLinePath(in: iRect, isDragLine)
				default:        return   curvedLinePath(in: iRect, kind: k)
			}
		}

		return ZBezierPath()
	}

	func drawLine() {
		if  let      child = childWidget {
			let       kind = lineKind
			let       rect = lineRect(to: child, kind: kind)
			let       path = linePath(in:  rect, kind: kind)
			path.lineWidth = CGFloat(gLineThickness)
			if  let  color = child.widgetZone?.color {

				if  isCircularMode {
					ZBezierPath(rect: gMapView!.bounds).setClip()

					if  gDebugDraw {
						rect.drawColoredRect(color)
					}
				}

				color.setStroke()
				path.stroke()
			}
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

	override func draw(_ phase: ZDrawPhase) {
		switch phase {
			case .pLines:
				drawLine()
			case .pDotsAndHighlight:
				revealDot?.draw()
				dragDot?  .draw()
		}
	}

}
