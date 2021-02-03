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

	var childCount    : Int             = 0
	var isDrop        : Bool            = false
	var filled        : Bool            = false
	var isReveal      : Bool            = false
	var showSideDot   : Bool            = false
	var isBookmark    : Bool            = false
	var isNotemark    : Bool            = false
	var showAccess    : Bool            = false
	var showList      : Bool            = false
	var traitType     : String          = ""
	var sideDotRadius : Double          = 4.0
	var fill          : ZColor          = gBackgroundColor
	var color         : ZColor          = gDefaultTextColor
	var accessType    : ZDecorationType = .vertical

}

class ZoneDot: ZView, ZGestureRecognizerDelegate, ZTooltips {

    // MARK:- properties
    // MARK:-

    weak var     widget: ZoneWidget?
    var        innerDot: ZoneDot?
    var       dragStart: CGPoint?
    var        isReveal: Bool    = true
    var      isInnerDot: Bool    = false
	var      isDragDrop: Bool    { return widgetZone == gDragDropZone }
	var dragDotIsHidden: Bool    { return widgetZone?.dragDotIsHidden ?? true }
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
			return isDragDrop || zone.canTravel || zone.count > 0
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
			let childlessTraveller = zone.canTravel && zone.count == 0

			return !zone.expanded || childlessTraveller
		}
	}

    // MARK:- initialization
    // MARK:-

    func setupForWidget(_ iWidget: ZoneWidget, asReveal: Bool) {
        isReveal = asReveal
        widget   = iWidget
		
        if  isInnerDot {
			snp.setLabel("<\(isReveal ? "r" : "d")> \(widgetZone?.zoneName ?? "unknown")")
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
			snp.setLabel("<\(isReveal ? "r" : "d")> \(widgetZone?.zoneName ?? "unknown")")
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
		updateTooltips()
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

		path.fill()
	}

	func drawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
        let   thickness = CGFloat(gLineThickness)
		var        path = ZBezierPath()

		if  parameters.isReveal {
			let toRight = parameters.showList
			path        = ZBezierPath.bloatedTrianglePath(aimedRight: toRight, in: iDirtyRect)
		} else {
			path        = ZBezierPath(ovalIn: iDirtyRect.insetEquallyBy(thickness))
		}

		path.lineWidth  = thickness * 2.0
		path.flatness   = 0.0001

		path.stroke()
		path.fill()
	}

	func drawTinyCountDots(_ iDirtyRect: CGRect, parameters: ZDotParameters) {
		let count = parameters.childCount

		if  count > 0 {
			let  frame = iDirtyRect.offsetEquallyBy(-0.1)
			let  color = parameters.isDrop ? gActiveColor : parameters.color
			let radius = ((Double(frame.size.height) * gLineThickness / 24.0) + 0.4)

			drawTinyDots(surrounding: frame, count: count, radius: radius, color: color)
		}
	}


    func drawWriteAccessDecoration(of type: ZDecorationType, in iDirtyRect: CGRect) {
        var thickness = CGFloat(gLineThickness + 0.1) * ratio
        var      path = ZBezierPath(rect: CGRect.zero)
        var      rect = CGRect.zero

        switch type {
        case .vertical:
            rect      = CGRect(origin: CGPoint(x: iDirtyRect.midX - (thickness / 2.0), y: iDirtyRect.minY),                   size: CGSize(width: thickness, height: iDirtyRect.size.height))
            path      = ZBezierPath(rect: rect)
        case .sideDot:
            thickness = (thickness + 2.5) * iDirtyRect.size.height / 12.0
            rect      = CGRect(origin: CGPoint(x: iDirtyRect.maxX -  thickness - 1.0,   y: iDirtyRect.midY - thickness / 2.0), size: CGSize(width: thickness, height: thickness))
            path      = ZBezierPath(ovalIn: rect)
        }

        path.fill()
    }

	func drawCenterBookmarkDot(in iDirtyRect: CGRect, notemarkColor: ZColor? = nil) {
		var      rect = iDirtyRect.insetEquallyBy(fraction: 0.25)
		var      path = ZBezierPath(ovalIn: rect)
		path.flatness = 0.0001

		path.fill()

		if  let color = notemarkColor {
			rect      = rect.insetBy(fractionY: 0.4)
			path      = ZBezierPath(rect: rect)

			color.setFill()
			path.fill()
		}
	}

	func drawTraitIndicator(for string: String, isFilled: Bool, color: ZColor, isForMap: Bool = true, in iDirtyRect: CGRect) {
		let    width = CGFloat(gDotHeight - 2.0) * ratio
		let     font = ZFont.boldSystemFont(ofSize: width)
		let     size = string.sizeWithFont(font)
		let    ratio = ZTraitType(rawValue: string)?.heightRatio ?? 1.0
		let   height = size.height * ratio + (isForMap ? 1.0 : -8.0)
		let   xDelta = (iDirtyRect.width - size.width) / CGFloat(2.0)
		let   yDelta = (height - iDirtyRect.height) / CGFloat(4.0)
		let     rect = iDirtyRect.insetBy(dx: xDelta, dy: yDelta).offsetBy(dx: 0.0, dy: (height / 12.0) - 1)

		string.draw(in: rect, withAttributes: [.foregroundColor : color, .font: font])
	}

	func drawInnerDot(_ iDirtyRect: CGRect, _ parameters: ZDotParameters) {
		let decorationFillColor = parameters.filled ? gBackgroundColor : parameters.color

		parameters.color.setStroke()
		parameters.fill .setFill()

		// //////
		// DOT //
		// //////

		drawMainDot(in: iDirtyRect, using: parameters)

		if      parameters.isReveal {
			if  parameters.isBookmark || parameters.isNotemark {

				// //////////////////
				// TINY CENTER DOT //
				// //////////////////

				gBackgroundColor.setFill()
				drawCenterBookmarkDot(in: iDirtyRect, notemarkColor: parameters.isNotemark ? parameters.color : nil)
			} else if parameters.traitType != "" {

				// //////////////////
				// TRAIT INDICATOR //
				// //////////////////

				drawTraitIndicator(for: parameters.traitType, isFilled: parameters.filled, color: decorationFillColor, in: iDirtyRect)
			}
		} else if parameters.showAccess {

			// ///////////////////////////
			// WRITE-ACCESS DECORATIONS //
			// ///////////////////////////

			decorationFillColor.setFill()
			drawWriteAccessDecoration(of: parameters.accessType, in: iDirtyRect)
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

			if !parameters.isBookmark,
			    gCountsMode == .dots {

				drawTinyCountDots(iDirtyRect, parameters: parameters)
			}
		} else if parameters.showSideDot {

			// ////////////////////////////////
			// HIGHLIGHT OF CURRENT FAVORITE //
			// ////////////////////////////////

			parameters.color.withAlphaComponent(0.7).setFill()
			drawSmallMapSideDot(in: iDirtyRect, parameters)
		}
	}

    override func draw(_ iDirtyRect: CGRect) {
        super.draw(iDirtyRect)

		if  isVisible(iDirtyRect),
			let parameters = widgetZone?.dotParameters(isFilled, isReveal) {
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
