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

	var childCount    = 0
	var sideDotOffset = CGPoint.zero
	var typeOfTrait   = kEmpty
	var isDrop        = false
	var filled        = false
	var isReveal      = false
	var isDragged     = false
	var isGrouped     = false
	var isGroupOwner  = false
	var badRecordName = false
	var hasTargetNote = false
	var hasTarget     = false
	var showList      = false
	var showAccess    = false
	var showSideDot   = false
	var fill          = gBackgroundColor
	var color         = kDefaultIdeaColor
	var accessType    = ZDecorationType.vertical

}

@objc (ZoneDot)
class ZoneDot: ZPseudoView, ZToolTipper {

    // MARK: - properties
    // MARK: -

	var                   line : ZoneLine?
	weak var            widget : ZoneWidget?
	var                  ratio : CGFloat         { return widget?.mapReduction ?? 1.0 }
	var             widgetZone : Zone?           { return widget?.widgetZone }
	override var    controller : ZMapController? { return widget?.controller }
	override var zClassInitial : String          { return isReveal ? "R" : "D" }
	override var     debugName : String          { return widgetZone?.zoneName ?? kUnknown }
	var        dragDotIsHidden : Bool            { return widgetZone?.dragDotIsHidden ?? true }
	var               isReveal = true

	var dotIsVisible: Bool {
		guard let zone = widgetZone else {
			return false
		}

		if !isReveal {
			return !zone.isFavoritesHere
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
				filled = ((!zone.isExpanded || (zone.isTraveller && zone.count == 0)) && isLinearMode) != isHovering
			} else {
				filled =   zone.isGrabbed   || isHovering
			}
		}

		return  filled
	}

	// MARK: - initialization
	// MARK: -

    func setupForWidget(_ w: ZoneWidget?, asReveal: Bool) {
        isReveal = asReveal
        widget   = w

		updateDotDrawnSize()
	}
	
	override func setupDrawnView() {
		super.setupDrawnView()

		if  let     m = absoluteView as? ZMapView {
			drawnView = m.decorationsView
		}
	}

    // MARK: - draw
    // MARK: -

	func drawFavoriteSideDot(in iDirtyRect: CGRect, _ parameters: ZDotParameters) {
		guard let      c = controller ?? gHelpController else { return } // for help dots, widget and controller are nil; so use help controller
		let       radius = c.sideDotRadius
		let     diameter = radius * 2.0
		let         size = CGSize.squared(diameter)
		let       origin = iDirtyRect.center - CGPoint.squared(radius) + parameters.sideDotOffset
		let         rect = CGRect(origin: origin, size: size)
		let         path = ZBezierPath(ovalIn: rect)
		path.lineWidth   = c.coreThickness * 1.2
		path.flatness    = kDefaultFlatness

		path.fill()
	}

	func drawTinyCountDots(_ iDirtyRect: CGRect, parameters: ZDotParameters) {
		guard let    c = controller ?? gHelpController else { return } // for help dots, widget and controller are nil; so use help controller
		let count      = parameters.childCount
		if  count      > 1 {
			let  frame = iDirtyRect.offsetEquallyBy(-0.1)
			let  color = parameters.isDrop ? gActiveColor : parameters.color
			let radius = ((Double(frame.size.height * c.coreThickness) / 24.0) + 0.4)

			drawTinyDots(surrounding: frame, count: count, radius: radius, color: color)
		}
	}

	func drawWriteAccessDecoration(of type: ZDecorationType, in iDirtyRect: CGRect) {
		guard let   c = controller ?? gHelpController else { return } // for help dots, widget and controller are nil; so use help controller
		var thickness = CGFloat(c.coreThickness + 0.5) * ratio
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

		path.flatness = kDefaultFlatness

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
		if  let      c = controller ?? gHelpController { // for help dots, widget and controller are nil; so use help controller
			let   text = string == "h" ? "=" : string == "n" ? "+" : string == "w" ? "&" : string
			let factor = CGFloat(string == "w" ? 1.07 : 0.93)
			let  width = c.dotWidth * ratio
			let   font = ZFont.boldSystemFont(ofSize: width)
			let offset = text.sizeWithFont(font).dividedInHalf
			let  point = iDirtyRect.center.offsetBy(-offset.width, -offset.height * factor)

			text.draw(at: point, withAttributes: [.foregroundColor : color, .font: font])
		}
	}

	func drawRevealDotDecorations(_ iDirtyRect: CGRect, _ parameters: ZDotParameters) {
		let fillColor = parameters.filled ? gBackgroundColor : parameters.color

		if parameters.hasTarget || parameters.hasTargetNote {

			// //////////////////////////////// //
			// TINY CENTER BOOKMARK DECORATIONS //
			// //////////////////////////////// //

			fillColor.setFill()
			drawCenterBookmarkDecorations(in: iDirtyRect, hasNote: parameters.hasTargetNote)
		}
	}

	func drawDotInterior(_ iDirtyRect: CGRect, _ parameters: ZDotParameters) {
		let fillColor = parameters.filled ? gBackgroundColor : parameters.color

		if  parameters.typeOfTrait != kEmpty, controller?.inCircularMode != isReveal {

			// ///////////////// //
			// TRAIT DECORATIONS //
			// ///////////////// //

			drawTraitDecoration(in: iDirtyRect, string: parameters.typeOfTrait, color: fillColor)
		}

		if  parameters.isReveal {
			drawRevealDotDecorations(iDirtyRect, parameters)
		} else {
			fillColor.setFill()

			if  parameters.isGrouped, controller?.inCircularMode == false {

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

	func drawDotExterior(_ iDirtyRect: CGRect, _ parameters: ZDotParameters) {
		if  parameters.showSideDot,
			!parameters.isReveal {

			// ////////////////////////////////
			// INDICATE CURRENT IN SMALL MAP //
			// ////////////////////////////////

			let color = parameters.color.withAlphaComponent(0.7)

			color.setFill()
			color.setStroke()
			drawFavoriteSideDot(in: iDirtyRect, parameters)
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

	func drawDot(_ iDirtyRect: CGRect, _ parameters: ZDotParameters) {
		if  (parameters.isDragged && !parameters.isReveal) || (parameters.isDrop && parameters.isReveal) {
			gActiveColor.setStroke()
			gActiveColor.setFill()
		} else {
			parameters.color.setStroke()
			parameters .fill.setFill()
		}

		drawMainDot    (iDirtyRect, parameters)
		drawDotExterior(iDirtyRect, parameters)
		drawDotInterior(iDirtyRect, parameters)
	}

    func draw() {
		let rect  = absoluteFrame
		if  rect.hasSize, dotIsVisible,
			let p = widgetZone?.plainDotParameters(isFilled, isReveal, isDragDrop) {

			if  isCircularMode, gDebugDraw {
				absoluteHitRect.drawColoredRect(.blue, radius: 2.0, thickness: 1.0)
			}
			
			drawDot(rect, p)
		}
	}

}
