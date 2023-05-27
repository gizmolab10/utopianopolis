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
	var isDrop        = false
	var isReveal      = false
	var isFilled      = false
	var isCircle      = false
	var isDragged     = false
	var isGrouped     = false
	var isGroupOwner  = false
	var badRecordName = false
	var hasTargetNote = false
	var hasTarget     = false
	var showList      = false
	var showAccess    = false
	var showSideDot   = false
	var traitTypes    = StringsArray()
	var fill          = gBackgroundColor
	var color         = kDefaultIdeaColor
	var accessType    = ZDecorationType.vertical

}

@objc (ZoneDot)
class ZoneDot: ZPseudoView, ZToolTipper {

    // MARK: - properties
    // MARK: -

	var               isReveal = true
	var           traitWidgets = [ZTraitWidget]()
	var                   line : ZoneLine?
	weak var            widget : ZoneWidget?
	override var    controller : ZMapController? { return widget?.controller }
	override var zClassInitial : String          { return isReveal ? "R" : "D" }
	override var     debugName : String          { return widgetZone?.zoneName ?? kUnknown }
	var                  ratio : CGFloat         { return widget?.mapReduction ?? 1.0 }
	var             widgetZone : Zone?           { return widget?.widgetZone }
	var        dragDotIsHidden : Bool            { return widgetZone?.dragDotIsHidden ?? true }

	var dotIsVisible: Bool {
		guard let zone = widgetZone else {
			return false
		}

		if !isReveal {
			return !zone.isFavoritesHere
		}   else {
			return  isDragDrop       ||
				(   zone.isTraveller ||
					zone.hasChildren)
		}
    }

	var isFilled: Bool {
		var     filled = false
		if  let zone   = widgetZone {
			if  isReveal {
				filled = ((!zone.isExpanded || (zone.isTraveller && !zone.hasChildren)) && isLinearMode) != isHovering
			} else {
				filled =   zone.isGrabbed   || isHovering
			}
		}

		return  filled
	}

	// MARK: - initialization
	// MARK: -

    func setupForWidget(_ w: ZoneWidget?, asReveal: Bool) {
        isReveal       = asReveal
        widget         = w
		if  isReveal, widgetZone?.hasMultipleTraits ?? false,
			let traits = widgetZone?.traits.map({ $0.value.traitType?.rawValue.convertedTrait ?? kEmpty }) {
			setupForTraits(traits)
		}

		updateDotDrawnSize()
	}

	func setupForTraits(_ traits: StringsArray) {
		let     start = kPI / 10.0 * Double(traits.count == 3 ? 12 : 11)
		let    angles = 10.anglesArray(startAngle: start, clockwise: false, max: traits.count)
		for (index, trait) in traits.enumerated() {
			let t = ZTraitWidget(view: absoluteView, with: trait, at: angles[index], around: self)

			t.updateTraitWidgetDrawnSize()
			traitWidgets.append(t)
		}
	}

	@discardableResult func updateDotDrawnSize() -> CGSize {
		drawnSize = controller?.dotSize(forReveal: isReveal) ?? .zero

		return drawnSize
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
		guard let      c = controller ?? gHelpController else { return }    // for help dots, widget and controller are nil; so use help controller
		let  strokeColor = parameters.color.withAlphaComponent(0.7)
		let    fillColor = parameters.isFilled ? gBackgroundColor : strokeColor

		let       radius = c.sideDotRadius
		let     diameter = radius * 2.0
		let         size = CGSize.squared(diameter)
		let       origin = iDirtyRect.center - CGPoint.squared(radius) - CGPoint(x: c.dotThirdWidth, y: .zero)
		let         rect = CGRect(origin: origin, size: size)
		let         path = ZBezierPath(ovalIn: rect)
		path.lineWidth   = c.coreThickness * 2.0
		path.flatness    = kDefaultFlatness

		strokeColor.setStroke()
		fillColor  .setFill()
		path.stroke()
		path.fill()
	}

	func drawTinyCountDots(_ rect: CGRect, parameters: ZDotParameters) {
		guard let    c = controller ?? gHelpController else { return } // for help dots, widget and controller are nil; so use help controller
		let count      = parameters.childCount
		if  count      > 0 {
			let  color = parameters.isDrop ? gActiveColor : parameters.color
			let radius = rect.size.height * c.coreThickness / 13.0

			drawTinyDots(surrounding: rect, count: count, radius: radius, color: color)
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
			case kEquals,
				"+": return 0.9
			default: return .zero
		}
	}

	func drawTraitDecorations(in iDirtyRect: CGRect, _ parameters: ZDotParameters, isForMainMap: Bool = true) {
		if  let        c = controller ?? gHelpController {            // for help dots, widget and controller are nil; so use help controller
			let   string = parameters.traitTypes[0].convertedTrait    // we get here only if exactly one trait type
			let  dCenter = iDirtyRect.center
			let    width = c.dotWidth * 1.3
			let     font = ZFont.systemFont(ofSize: width)
			let     flag = parameters.isFilled
			let    color = flag ? gBackgroundColor : parameters.color
//			let altColor = flag ? parameters.color : gBackgroundColor
			let     size = string.sizeWithFont(font)
			let   offset = size.dividedInHalf.multiplyBy(CGSize(width: 1.0, height: 0.8))
			let   origin = dCenter.retreatBy(offset)
			let     rect = CGRect(origin: origin, size: size)

			string.draw(in: rect, withAttributes: [.foregroundColor : color, .font: font])
		}
	}

	func drawRevealDotDecoration(_ iDirtyRect: CGRect, _ parameters: ZDotParameters) {
		let fillColor = parameters.isFilled ? gBackgroundColor : parameters.color

		if  parameters.hasTarget || parameters.hasTargetNote {

			// //////////////////////////////// //
			// TINY CENTER BOOKMARK DECORATIONS //
			// //////////////////////////////// //

			fillColor.setFill()
			drawCenterBookmarkDecorations(in: iDirtyRect, hasNote: parameters.hasTargetNote)
		}
	}

	func drawDotInterior(_ iDirtyRect: CGRect, _ parameters: ZDotParameters) {
		if  parameters.traitTypes.count == 1, controller?.inCircularMode != isReveal {

			// ///////////////// //
			// TRAIT DECORATIONS //
			// ///////////////// //

			drawTraitDecorations(in: iDirtyRect, parameters)
		}

		if  parameters.isReveal {

			// //////////////////// //
			// BOOKMARK DECORATIONS //
			// //////////////////// //

			drawRevealDotDecoration(iDirtyRect, parameters)
		} else {
			let fillColor = parameters.isFilled ? gBackgroundColor : parameters.color
			fillColor.setFill()

			if  parameters.isGrouped, !(controller?.inCircularMode ?? false) {

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
		if !parameters.isReveal,
			parameters.showSideDot {

			// ///////////////////////////////// //
			// INDICATE CURRENT IN FAVORITES MAP //
			// ///////////////////////////////// //

			drawFavoriteSideDot(in: iDirtyRect, parameters)
		} else if  isLinearMode, parameters.isReveal {
			if gCountsMode == .dots,
			   !parameters.hasTarget,
			   !parameters.showList {

				// /////////////// //
				// TINY COUNT DOTS //
				// /////////////// //

				drawTinyCountDots(iDirtyRect, parameters: parameters)
			}

			for traitWidget in traitWidgets {
				var      p = parameters
				p.isFilled = traitWidget.isHovering

				if  p.isFilled {
					noop()
				}

				traitWidget.draw(p)
			}
		}
	}

	func drawDot(_ iDirtyRect: CGRect, _ parameters: ZDotParameters) {
		if (parameters.isDragged && !parameters.isReveal) || (parameters.isDrop && parameters.isReveal) {
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
			let z = widgetZone {

			if  isCircularMode, gDebugDraw {
				absoluteHitRect.drawColoredRect(.blue, radius: 2.0, thickness: 1.0)
			}
			
			drawDot(rect, z.plainDotParameters(isFilled, isReveal, isDragDrop))
		}
	}

}
