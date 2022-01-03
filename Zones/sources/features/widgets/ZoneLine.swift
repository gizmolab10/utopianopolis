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
		
		if  dragDot     == nil {
			let       c  = childWidget
			if  drag    != nil {
				dragDot  = drag
			} else if c != nil, !c!.hideDragDot,
				let   z  = c!.widgetZone, z.isShowing {
				dragDot  = ZoneDot(view: absoluteView)
			}

			dragDot?.line = self
			
			addSubpseudoview(dragDot)
			dragDot?.setupForWidget(c, asReveal: false)
		}
	}

	var lineKind : ZLineCurve {
		if  isLinearMode,
			let     dot = dragDot,
			let    zone = parentWidget?.widgetZone, zone.count > 1,
			let    kind = lineKind(to: dot.absoluteFrame) {
			return kind
		}

		return .straight
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

	func drawLine(in color: ZColor) {
		let       kind = lineKind
		let       rect = lineRect(for: kind)
		let       path = linePath(in: rect, kind: kind)
		path.lineWidth = CGFloat(gLineThickness)

		if  let  p = parentWidget?.widgetZone, !p.isExpanded {
			return
		}

		if  rect.hasZeroSize {
			return
		}

		if  isCircularMode {
			ZBezierPath.setClip(to: gMapView!.bounds)
		}

		color.setStroke()
		path.stroke()
	}

	func drawDragLineAndDot() {
		let               rect = absoluteDropDragDotRect
		dragDot?.absoluteFrame = rect

		gActiveColor.setFill()
		gActiveColor.setStroke()
		ZBezierPath(ovalIn: rect).fill()
		drawLine(in: gActiveColor)
	}

	func drawLine() {
		if  let other = childWidget ?? parentWidget,
			let color = other.widgetZone?.color {
			drawLine(in: color)
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
