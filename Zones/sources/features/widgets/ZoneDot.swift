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
	var sideDotRadius  = 4.0
	var traitType      = kEmpty
	var isDrop         = false
	var filled         = false
	var isReveal       = false
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

class ZoneDot: ZView, ZGestureRecognizerDelegate, ZTooltips {

    // MARK:- properties
    // MARK:-

    weak var     widget: ZoneWidget?
    var        innerDot: ZoneDot?
    var       dragStart: CGPoint?
	var         isHover: Bool    = false
    var        isReveal: Bool    = true
    var      isInnerDot: Bool    = false
	var dragDotIsHidden: Bool    { return widgetZone?.dragDotIsHidden ?? true }
	var      isDragDrop: Bool    { return widget == gDropWidget }
    var      widgetZone: Zone?   { return widget?.widgetZone }
	var           ratio: CGFloat { return widget?.ratio ?? 1.0 }
	var   innerDotWidth: CGFloat { return ratio * CGFloat(isReveal ? gDotHeight : dragDotIsHidden ? 0.0 : gDotWidth) }
	var  innerDotHeight: CGFloat { return ratio * CGFloat(gDotHeight) }

    var innerOrigin: CGPoint? {
        if  let inner = innerDot {
            let  rect = inner.convert(inner.bounds, to: self)

            return rect.origin
        }

        return nil
    }


    var innerExtent: CGPoint? {
        if  let inner = innerDot {
            let  rect = inner.convert(inner.bounds, to: self)

            return rect.extent
        }

        return nil
    }

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

			return !zone.expanded || childlessTraveller
		}
	}

    // MARK:- initialization
    // MARK:-

    func setupForWidget(_ iWidget: ZoneWidget, asReveal: Bool) {
        isReveal = asReveal
        widget   = iWidget
		
        if  isInnerDot {
			snp.setLabel("<\(isReveal ? "r" : "d")> \(widgetZone?.zoneName ?? kUnknown)")
            snp.removeConstraints()
            snp.makeConstraints { make in
                let  size = CGSize(width: innerDotWidth, height: innerDotHeight)

                make.size.equalTo(size)
            }

            setNeedsDisplay(frame)
        } else {
            if  innerDot            == nil {
                innerDot             = ZoneDot()
                innerDot!.isInnerDot = true

                addSubview(innerDot!)
            }

            innerDot?.setupForWidget(iWidget, asReveal: isReveal)
			snp.setLabel("<\(isReveal ? "r" : "d")> \(widgetZone?.zoneName ?? kUnknown)")
            snp.removeConstraints()
            snp.makeConstraints { make in
                var   width = !isReveal && dragDotIsHidden ? CGFloat(0.0) : (gGenericOffset.width * 2.0) - (gGenericOffset.height / 6.0) - 42.0 + innerDotWidth
                let  height = innerDotHeight + 5.0 + (gGenericOffset.height * 3.0)

				if !iWidget.type.isBigMap {
                    width  *= kSmallMapReduction
                }

                make.size.equalTo(CGSize(width: width, height: height))
                make.center.equalTo(innerDot!)
            }
        }

		#if os(iOS)
		backgroundColor = kClearColor
		#endif

        updateConstraints()
        setNeedsDisplay()
		updateTracking()
		updateTooltips()
    }

	// MARK:- hover
	// MARK:-

	func updateTracking() { if !isInnerDot { addTracking(for: frame) } }

	override func mouseEntered(with event: ZEvent) {
		innerDot?.isHover = true

		super.mouseEntered(with: event)
		innerDot?.setNeedsDisplay()
	}

	override func mouseExited(with event: ZEvent) {
		innerDot?.isHover = false

		super.mouseExited(with: event)
		innerDot?.setNeedsDisplay()
	}

    // MARK:- draw
    // MARK:-

    func isVisible(_ rect: CGRect) -> Bool {
        return isVisible && window?.contentView?.bounds.intersects(rect) ?? false
    }

	func drawSmallMapSideDot(in iDirtyRect: CGRect, _ parameters: ZDotParameters) {
		let       radius = parameters.sideDotRadius
		let   tinyRadius =     radius * 0.7
		let tinyDiameter = tinyRadius * 2.0
		let       center = iDirtyRect.center
		let            x = center.x - CGFloat(tinyDiameter + radius)
		let            y = center.y - CGFloat(tinyRadius)
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
        let  thickness = CGFloat(gLineThickness)
		var       path = ZBezierPath()

		if  parameters.isReveal {
			path       = ZBezierPath.bloatedTrianglePath(aimedRight: parameters.showList, in: iDirtyRect)
		} else {
			path       = ZBezierPath(ovalIn: iDirtyRect.insetEquallyBy(thickness))
		}

		path.lineWidth = thickness * 2.0
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
		if  parameters.isGroupOwner {
			let (a,b) = iDirtyRect.insetEquallyBy(fraction: 0.25).twoDotsVertically(fractionalDiameter: 0.7)
			let  path = ZBezierPath(ovalIn: a)

			path.append(ZBezierPath(ovalIn: b))
			path.fill()
		} else {
			let  rect = iDirtyRect.insetEquallyBy(fraction: 0.10).centeredHorizontalLine(thick: 1.25)

			ZBezierPath(rect: rect).fill()
		}
	}

	func drawStringDecoration(in iDirtyRect: CGRect, string: String, color: ZColor, isForMap: Bool = true) {
		let  width = CGFloat(gDotHeight - 2.0) * ratio
		let   font = ZFont.boldSystemFont(ofSize: width)
		let   size = string.sizeWithFont(font)
		let  ratio = ZTraitType(rawValue: string)?.heightRatio ?? 1.0
		let height = size.height * ratio + (isForMap ? 1.0 : -8.0)
		let xDelta = (iDirtyRect.width - size.width) / CGFloat(2.0)
		let yDelta = (height - iDirtyRect.height) / CGFloat(4.0)
		let   rect = iDirtyRect.insetBy(dx: xDelta, dy: yDelta).offsetBy(dx: 0.0, dy: (height / 12.0) - 1)

		string.draw(in: rect, withAttributes: [.foregroundColor : color, .font: font])
	}

	func drawInnerRevealDot(_ iDirtyRect: CGRect, _ parameters: ZDotParameters) {
		let fillColor = parameters.filled ? gBackgroundColor : parameters.color

		if parameters.hasTarget || parameters.hasTargetNote {
//			let fillColor = parameters.filled ? parameters.color : gBackgroundColor

			// //////////////////////////////// //
			// TINY CENTER BOOKMARK DECORATIONS //
			// //////////////////////////////// //

			fillColor.setFill()
			drawCenterBookmarkDecorations(in: iDirtyRect, hasNote: parameters.hasTargetNote)
		} else if parameters.traitType != kEmpty {

			// ///////////////// //
			// TRAIT DECORATIONS //
			// ///////////////// //

			drawStringDecoration(in: iDirtyRect, string: parameters.traitType, color: fillColor)
		}
	}

	func drawInnerDot(_ iDirtyRect: CGRect, _ parameters: ZDotParameters) {
		let decorationFillColor = parameters.filled ? gBackgroundColor : parameters.color

		parameters.color.setStroke()
		parameters.fill .setFill()

		// //////// //
		// MAIN DOT //
		// //////// //

		drawMainDot(in: iDirtyRect, using: parameters)

		if      parameters.isReveal {
			drawInnerRevealDot(iDirtyRect, parameters)
		} else {
			decorationFillColor.setFill()

			if  parameters.isGrouped {

				// //////////////////// //
				// GROUPING DECORATIONS //
				// //////////////////// //

				drawGroupingDecorations(for: parameters, in: iDirtyRect)
			}

			if parameters.showAccess {

				// /////////////////////// //
				// WRITE-ACCESS DECORATION //
				// /////////////////////// //

				drawWriteAccessDecoration(of: parameters.accessType, in: iDirtyRect)
			}
		}

	}

	func drawOuterDot(_ iDirtyRect: CGRect, _ parameters: ZDotParameters) {

		// /////////////////////////////
		// MOSTLY INVISIBLE OUTER DOT //
		// /////////////////////////////

		if  parameters.isReveal {

			// //////////////////
			// TINY COUNT DOTS //
			// //////////////////

			if !parameters.hasTarget,
			    gCountsMode == .dots {

				drawTinyCountDots(iDirtyRect, parameters: parameters)
			}
		} else if parameters.showSideDot {

			// ////////////////////////////////
			// HIGHLIGHT OF CURRENT FAVORITE //
			// ////////////////////////////////

			let color = parameters.color.withAlphaComponent(0.7)

			color.setFill()
			color.setStroke()
			drawSmallMapSideDot(in: iDirtyRect, parameters)
		}
	}

    override func draw(_ iDirtyRect: CGRect) {
        super.draw(iDirtyRect)

		if  isVisible(iDirtyRect),
			let parameters = widgetZone?.plainDotParameters(isFilled != isHover, isReveal) {
			if  isInnerDot {
				drawInnerDot(iDirtyRect, parameters)
			} else if  innerDot != nil,
				let rect = innerDot?.frame.offsetBy(dx: -0.1, dy: -0.1),
				let zone = widgetZone,
				(!zone.expanded || zone.isBookmark) {
				drawOuterDot(rect, parameters)
			}
		}
    }

}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}
