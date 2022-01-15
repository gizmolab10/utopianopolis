//
//  ZoneDot.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/27/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

import SnapKit

enum ZDecorationType: Int {
	case vertical
	case sideDot
}

struct  ZDotParameters {

	var childCount     = 0
	var verticleOffset = 0.0
	var sideDotRadius  = 4.0
	var typeOfTrait    = kEmpty
	var isDrop         = false
	var filled         = false
	var isReveal       = false
	var isDragged      = false
	var isGrouped      = false
	var isGroupOwner   = false
	var badRecordName  = false
	var hasTargetNote  = false
	var hasTarget      = false
	var showList       = false
	var showAccess     = false
	var showSideDot    = false
	var fill           = gBackgroundColor
	var color          = gDefaultTextColor
	var accessType     = ZDecorationType.vertical

}

@objc (ZoneDot)
class ZoneDot: ZPseudoView {

    // MARK: - properties
    // MARK: -

	var                line : ZoneLine?
	weak var         widget : ZoneWidget?
	override var controller : ZMapController? { return widget?.controller }
	var     dragDotIsHidden : Bool            { return widgetZone?.dragDotIsHidden ?? true }
    var          widgetZone : Zone?           { return widget?.widgetZone }
	var               ratio : CGFloat         { return widget?.mapReduction ?? 1.0 }
	var            isReveal = true

	var dotIsVisible: Bool {
		guard let zone = widgetZone else {
			return false
		}

		if !isReveal {
			return !zone.isSmallMapHere
		}   else {
			return  isDragDrop       ||
				(   zone.isTraveller ||
					zone.count > 0)
		}
    }

	var isFilled: Bool {
		var     filled = false
		if  let zone   = widgetZone {
			if  isReveal {
				filled = (!zone.isExpanded || (zone.isTraveller && zone.count == 0)) && isLinearMode
			} else {
				filled =   zone.isGrabbed
			}
		}

		return  filled != isHovering
	}

	// MARK: - initialization
	// MARK: -

	@discardableResult func updateDotDrawnSize() -> CGSize {
		let inBig = widget?.type.isBigMap ?? true
		drawnSize = gDotSize(forReveal: isReveal, forBigMap: inBig)

		return drawnSize
	}

    func setupForWidget(_ w: ZoneWidget?, asReveal: Bool) {
        isReveal = asReveal
        widget   = w

		updateDotDrawnSize()
	}
	
	override func setupDrawnView() {
		super.setupDrawnView()

		if  let     m = absoluteView as? ZMapView {
			drawnView = m.linesAndDotsView
		}
	}

    // MARK: - draw
    // MARK: -

	func drawSmallMapSideDot(in iDirtyRect: CGRect, _ parameters: ZDotParameters) {
		let       radius = parameters.sideDotRadius
		let   tinyRadius =     radius * 0.7
		let tinyDiameter = tinyRadius * 2.0
		let       center = iDirtyRect.center
		let            x = center.x - CGFloat(tinyRadius + radius + 1.0)
		let            y = center.y - CGFloat(tinyRadius + parameters.verticleOffset)
		let         rect = CGRect(x: x, y: y, width: CGFloat(tinyDiameter), height: CGFloat(tinyDiameter))
		let         path = ZBezierPath(ovalIn: rect)
		path.lineWidth   = CGFloat(gLineThickness * 1.2)
		path.flatness    = 0.0001

		if  let     zone = widgetZone, zone.isInFavorites == gIsRecentlyMode {   // WTF?
			path.stroke()
		} else {
			path.fill()
		}
	}

	func drawTinyCountDots(_ iDirtyRect: CGRect, parameters: ZDotParameters) {
		let count      = parameters.childCount
		if  count      > 0 {
			let  frame = iDirtyRect.offsetEquallyBy(-0.1)
			let  color = parameters.isDrop ? gActiveColor : parameters.color
			let radius = ((Double(frame.size.height) * gLineThickness / 24.0) + 0.4)

			drawTinyDots(surrounding: frame, count: count, radius: radius, color: color)
		}
	}

    func drawWriteAccessDecoration(of type: ZDecorationType, in iDirtyRect: CGRect) {
        var thickness = CGFloat(gLineThickness + 0.5) * ratio
        var      path = ZBezierPath(rect: .zero)
        var      rect = CGRect.zero

        switch type {
        case .vertical:
			rect      = iDirtyRect.insetEquallyBy(fraction: 0.175).centeredVerticalLine(thick: thickness)
            path      = ZBezierPath(rect: rect)
        case .sideDot:
            thickness = (thickness + 2.0) * iDirtyRect.size.height / 12.0
            rect      = CGRect(origin: CGPoint(x: iDirtyRect.maxX -  thickness - 1.0,   y: iDirtyRect.midY - thickness / 2.0), size: CGSize.squared(thickness))
            path      = ZBezierPath(ovalIn: rect)
        }

        path.fill()
	}

	func drawCenterBookmarkDecorations(in iDirtyRect: CGRect, hasNote: Bool = false) {
		var rect = iDirtyRect.insetEquallyBy(fraction: 0.3)
		var path = ZBezierPath(ovalIn: rect)

		if  hasNote {
			rect = rect.insetEquallyBy(fraction: 0.2)
			path =      ZBezierPath(ovalIn: rect.offsetBy(fractionY: -0.7))
			path.append(ZBezierPath(ovalIn: rect.offsetBy(fractionY:  0.7)))
		}

		path.flatness = 0.0001

		path.fill()
	}

	func drawGroupingDecorations(for parameters: ZDotParameters, in iDirtyRect: CGRect) {
		var path      = ZBezierPath()

		if  parameters.isGroupOwner {
			let (a,b) = iDirtyRect.insetEquallyBy(fraction: 0.25).twoDotsVertically(fractionalDiameter: 0.7)
			path      = ZBezierPath(ovalIn: a)

			path.append(ZBezierPath(ovalIn: b))
		} else {
			let  rect = iDirtyRect.insetEquallyBy(fraction: 0.10).centeredHorizontalLine(thick: 1.25)
			path      = ZBezierPath(rect: rect)
		}

		path.fill()
	}

	func offsetFor(_ string: String) -> CGFloat {
		switch string {
			case "=", "+": return 0.9
			default:       return .zero
		}
	}

	func drawTraitDecoration(in iDirtyRect: CGRect, string: String, color: ZColor, angle: CGFloat = .zero, isForBigMap: Bool = true) {
		let   text = string == "h" ? "=" : string == "n" ? "+" : string
		let  width = gDotWidth * ratio
		let   font = ZFont.boldSystemFont(ofSize: width)
		let offset = text.sizeWithFont(font).dividedInHalf
		let  point = iDirtyRect.center.offsetBy(-offset.width, -offset.height * 0.93)

		text.draw(at: point, withAttributes: [.foregroundColor : color, .font: font])
	}

	func drawRevealDotDecorations(_ iDirtyRect: CGRect, _ parameters: ZDotParameters) {
		let fillColor = parameters.filled ? gBackgroundColor : parameters.color

		if parameters.hasTarget || parameters.hasTargetNote {

			// //////////////////////////////// //
			// TINY CENTER BOOKMARK DECORATIONS //
			// //////////////////////////////// //

			fillColor.setFill()
			drawCenterBookmarkDecorations(in: iDirtyRect, hasNote: parameters.hasTargetNote)
		} else if parameters.typeOfTrait != kEmpty {

			// ///////////////// //
			// TRAIT DECORATIONS //
			// ///////////////// //

			drawTraitDecoration(in: iDirtyRect, string: parameters.typeOfTrait, color: fillColor)
		}
	}

	func drawDot(_ iDirtyRect: CGRect, _ parameters: ZDotParameters) {
		let decorationFillColor = parameters.filled ? gBackgroundColor : parameters.color

		if  (parameters.isDragged && !parameters.isReveal) || (parameters.isDrop && parameters.isReveal) {
			gActiveColor.setStroke()
			gActiveColor.setFill()
		} else {
			parameters.color.setStroke()
			parameters .fill.setFill()
		}

		drawMainDot(in: iDirtyRect, using: parameters) // needed for dots help view

		if  parameters.isReveal {
			drawRevealDotDecorations(iDirtyRect, parameters)
		} else {
			decorationFillColor.setFill()

			if  parameters.isGrouped {

				// //////////////////// //
				// GROUPING DECORATIONS //
				// //////////////////// //

				drawGroupingDecorations(for: parameters, in: iDirtyRect)
			}

			if  parameters.showAccess {

				// /////////////////////// //
				// WRITE-ACCESS DECORATION //
				// /////////////////////// //

				drawWriteAccessDecoration(of: parameters.accessType, in: iDirtyRect)
			}
		}
	}

	func drawAroundDot(_ iDirtyRect: CGRect, _ parameters: ZDotParameters) {
		if  parameters.showSideDot,
			!parameters.isReveal {

			// ////////////////////////////////
			// INDICATE CURRENT IN SMALL MAP //
			// ////////////////////////////////

			let color = parameters.color.withAlphaComponent(0.7)

			color.setFill()
			color.setStroke()
			drawSmallMapSideDot(in: iDirtyRect, parameters)
		} else if  isLinearMode,
			gCountsMode == .dots,
			parameters.isReveal,
			!parameters.hasTarget,
			!parameters.showList {

			// //////////////////
			// TINY COUNT DOTS //
			// //////////////////

			drawTinyCountDots(iDirtyRect, parameters: parameters)
		}
	}

    func draw() {
		let rect   = absoluteFrame
		let drag   = gDragging.dragLine?.parentWidget?.widgetZone
		let isDrop = isDragDrop && drag != nil && drag == widgetZone
		if  rect.hasSize, dotIsVisible,
			let parameters = widgetZone?.plainDotParameters(isFilled, isReveal, isDrop) {

//			if  isCircularMode, gdebugdraw {
//				hitRect.drawColoredRect(.red, radius: 2.0, thickness: 1.0)
//			}
			
			drawDot      (rect, parameters)
			drawAroundDot(rect, parameters)
		}
	}

}
