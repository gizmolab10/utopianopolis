//
//  ZonesLine.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/26/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

enum ZLineCurveKind: Int {
	case below    = -1
	case straight =  0
	case above    =  1
}

@objc (ZoneLine)
class ZoneLine: ZPseudoView {

	var              length = CGFloat(25)
	var           dragAngle : CGFloat?
	var             dragDot : ZoneDot?
	var           revealDot : ZoneDot?
	var         childWidget : ZoneWidget?
	var        parentWidget : ZoneWidget?
	var            isCenter : Bool            { return  parentWidget?.isCenter ?? true }
	override var controller : ZMapController? { return (parentWidget ?? childWidget)?.controller }

	func addDots(reveal: ZoneDot? = nil, drag: ZoneDot? = nil) {
		if  let p                    = parentWidget {
			if  revealDot           == nil {
				revealDot            = reveal ?? ZoneDot(view: absoluteView)
				if  revealDot?.line == nil {
					revealDot?.line  = self
					
					addSubpseudoview(revealDot)
					revealDot?.setupForWidget(p, asReveal: true)
				}
			}
		}
		
		if  dragDot        == nil {
			if  drag       != nil {
				dragDot     = drag
			} else if let c = childWidget, !c.hideDragDot,
				let       z = c.widgetZone, z.isShowing {
				dragDot     = ZoneDot(view: absoluteView)
			}

			if  let       d = dragDot {
				d     .line = self

				addSubpseudoview(d)
				d.setupForWidget(childWidget, asReveal: false)
			}
		}
	}

	var lineKind : ZLineCurveKind {
		if  isLinearMode,
			let     dot = dragDot,
			let    zone = parentWidget?.widgetZone, zone.count > 1,
			let    kind = lineKind(to: dot.absoluteFrame) {
			return kind
		}

		if  self       == gDragging.dragLine,
			let    kind = gDragging.dropKind {
			return kind
		}

		return .straight
	}
	
	func linePath(in iRect: CGRect, kind: ZLineCurveKind?, isDragLine: Bool = false) -> ZBezierPath {
		if  let    k = kind {
			switch k {
				case .straight: return straightLinePath(in: iRect, isDragLine)
				default:        return   curvedLinePath(in: iRect, kind: k)
			}
		}

		return ZBezierPath()
	}

	func drawLine(using color: ZColor) {
		if  let  p = parentWidget?.widgetZone, !p.isExpanded, self != gDragging.dragLine {
			return
		}

		let       kind = lineKind
		let       rect = lineRect(for: kind)
		let  highlight = childWidget?.widgetZone?.siblingIndex == 0 && isCircularMode
		let       path = linePath(in: rect, kind: kind)
		path.lineWidth = CGFloat(highlight ? 2.0 : gLineThickness)

		if  rect.hasZeroSize {
			return
		}

		if  highlight, rect.size.hypotenuse > 30.0 {     // needs to be long enough to show as dashes
			path.addDashes()
		}

		if  let b = controller?.mapView?.bounds, isCircularMode {
			ZBezierPath.setClip(to: b)
		}

		color.setStroke()
		path.stroke()
	}

	func drawDragLineAndDot() {
		let  rect = draggingDotAbsoluteFrame
		let color = gActiveColor

		if  !rect.hasZeroSize,
			let relation = controller?.relationOf(rect.center, to: gDragging.dropWidget) {
			gDragging.dropRelation = relation
			gDragging.dropKind     = relation.lineCurveKind
			dragDot?.absoluteFrame = rect

			color.setFill()
			color.setStroke()
			ZBezierPath(ovalIn: rect.insetEquallyBy(gLineThickness)).fill() // draw dot
			drawLine(using: color)
		}
	}

	func drawLine() {
		if  let other = childWidget ?? parentWidget,
			let color = other.widgetZone?.color {
			drawLine(using: color)
		}
	}

	override func draw(_ phase: ZDrawPhase) {
		switch phase {
			case .pLines:
				drawLine()
			case .pDots:
				revealDot?.draw()
				dragDot?  .draw()
			default:
				break
		}
	}

}
