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

class ZoneDot: ZPseudoView {

    // MARK:- properties
    // MARK:-

    weak var     widget : ZoneWidget?
	var        isReveal = true
	var      isHovering = false
	var dragDotIsHidden : Bool    { return widgetZone?.dragDotIsHidden ?? true }
	var      isDragDrop : Bool    { return widget == gDropWidget }
    var      widgetZone : Zone?   { return widget?.widgetZone }
	var           ratio : CGFloat { return widget?.ratio ?? 1.0 }

	var isVisible: Bool {
		guard let zone = widgetZone else {
			return false
		}

		if  isReveal {
			return isDragDrop || zone.isTraveller || zone.count > 0
		}   else {
			return !zone.isSmallMapHere
		}
    }

	var isFilled: Bool {
		guard let zone = widgetZone else {
			return false
		}

		if !isReveal {
			return zone.isGrabbed
		} else {
			let childlessTraveller = zone.isTraveller && zone.count == 0

			return !zone.isExpanded || childlessTraveller
		}
	}

    // MARK:- initialization
    // MARK:-

	@discardableResult func updateSize() -> CGSize {
		let isBigMap = widget?.type.isBigMap ?? true
		drawnSize    = gDotSize(forReveal: isReveal, forBigMap: isBigMap)

		return drawnSize
	}

	func updateFrame(relativeTo textFrame: CGRect) {
		let    offset = CGPoint(drawnSize)//.multiplyBy(0.5))
		let    origin = isReveal ? textFrame.bottomRight : textFrame.origin.offsetBy(-offset.x, 0.0)
		absoluteFrame = CGRect(origin: origin, size: drawnSize)
	}

	func updateFrame(accountingFor childrenViewHeight : CGFloat = .zero, _ absolute: Bool = false) {
		if  absolute {
			updateAbsoluteFrame(toController: widget?.controller)
		} else if let textWidget = widget?.textWidget {
			let   drawnHeight = drawnSize.height
			let hasNoChildren = childrenViewHeight < drawnHeight
			let             y = hasNoChildren ? CGFloat.zero : (childrenViewHeight - drawnHeight) / CGFloat(2.0)
			var             x = textWidget.frame.minX - drawnSize.width

			if  isReveal {
				x             = textWidget.frame.maxX
			}

			frame = CGRect(origin: CGPoint(x: x, y: y), size: drawnSize)
		}
	}

    func setupForWidget(_ iWidget: ZoneWidget, asReveal: Bool) {
        isReveal = asReveal
        widget   = iWidget

		updateSize()
		updateTooltips()
	}

    // MARK:- draw
    // MARK:-

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

		if  let zone = widgetZone, zone.isInFavorites == gIsRecentlyMode {
			path.stroke()
		} else {
			path.fill()
		}
	}

	func drawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
		let  thickness = CGFloat(gLineThickness) * 2.0
		var       path = ZBezierPath()

		if  parameters.isReveal {
			path       = ZBezierPath.bloatedTrianglePath(aimedRight: parameters.showList, in: iDirtyRect)
		} else {
			path       = ZBezierPath(ovalIn: iDirtyRect.insetEquallyBy(thickness))
		}

		if  parameters.isDragged {
			gActiveColor.setFill()
			gActiveColor.setStroke()
		}

		path.lineWidth = thickness
		path .flatness = 0.0001

		path.stroke()
		path.fill()
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
            rect      = CGRect(origin: CGPoint(x: iDirtyRect.maxX -  thickness - 1.0,   y: iDirtyRect.midY - thickness / 2.0), size: CGSize(width: thickness, height: thickness))
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
			default:       return 0.0
		}
	}

	func drawTraitDecoration(in iDirtyRect: CGRect, string: String, color: ZColor, isForMap: Bool = true) {
		let    text = string == "h" ? "=" : string == "n" ? "+" : string
		let   width = CGFloat(gDotHeight - 2.0) * ratio
		let    font = ZFont.boldSystemFont(ofSize: width)
		let    size = text.sizeWithFont(font)
		let   ratio = ZTraitType(rawValue: text)?.heightRatio ?? 1.0
		let  height = size.height * ratio + (isForMap ? 1.0 : -8.0)
		let  xDelta = (iDirtyRect.width - size.width) / CGFloat(2.0)
		let  yDelta = (height - iDirtyRect.height) / CGFloat(4.0)
		let yOffset = (height / 12.0) - 1.0 + (offsetFor(text) * (isForMap ? 1.0 : kSmallMapReduction))
		let    rect = iDirtyRect.insetBy(dx: xDelta, dy: yDelta).offsetBy(dx: 0.0, dy: yOffset)

		text.draw(in: rect, withAttributes: [.foregroundColor : color, .font: font])
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

		parameters.color.setStroke()
		parameters .fill.setFill()
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

	func drawSurroundingDot(_ iDirtyRect: CGRect, _ parameters: ZDotParameters) {
		if  parameters.showSideDot {

			// ////////////////////////////////
			// INDICATE CURRENT IN SMALL MAP //
			// ////////////////////////////////

			let color = parameters.color.withAlphaComponent(0.7)

			color.setFill()
			color.setStroke()
			drawSmallMapSideDot(in: iDirtyRect, parameters)
		} else if  parameters.isReveal,
				   !parameters.hasTarget,
				   !parameters.showList,
				   gCountsMode == .dots {

			// //////////////////
			// TINY COUNT DOTS //
			// //////////////////

			drawTinyCountDots(iDirtyRect, parameters: parameters)
		}
	}

    override func draw(_ phase: ZDrawPhase) {
		if  isVisible,
			let parameters = widgetZone?.plainDotParameters(isFilled != isHovering, isReveal) {
			let     offset = absoluteFrame.height / -9.0
			let       rect = absoluteFrame.insetEquallyBy(fraction: 0.22).offsetBy(dx: 0.0, dy: offset)

			drawDot           (rect, parameters)
			drawSurroundingDot(rect, parameters)
		}
    }

}
