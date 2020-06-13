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


    var isDropTarget: Bool {
        if  let   index = widgetZone?.siblingIndex, !isReveal {
            let isIndex = gDragDropIndices?.contains(index)
            let  isDrop = widgetZone?.parentZone == gDragDropZone

            if isDrop && isIndex! {
                return true
            }
        }

        return false
    }

    var isVisible: Bool {
        if  isReveal,
			let zone = widgetZone {
            return isDragDrop || zone.canTravel || zone.count > 0
        }
        
        return true
    }

	var isFilled: Bool {
		if  let zone = widgetZone {
			if  !isReveal {
				return zone.isGrabbed
			} else {
				let childlessTraveller = zone.canTravel && zone.count == 0

				return !zone.showingChildren || childlessTraveller
			}
		}

		return false
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

				if !iWidget.type.isMap {
                    width  *= kFavoritesReduction
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

    enum ZDecorationType: Int {
        case vertical
        case sideDot
    }

    func isVisible(_ rect: CGRect) -> Bool {
        return isVisible && window?.contentView?.bounds.intersects(rect) ?? false
    }

    func drawFavoritesHighlight(in iDirtyRect: CGRect) {
		if  let          zone  = widgetZone, innerDot != nil, !zone.isFavoritesHere, !zone.isRootOfRecents {
            let      dotRadius = Double(innerDotWidth / 2.0)
            let     tinyRadius =  dotRadius * 0.7
            let   tinyDiameter = tinyRadius * 2.0
            let         center = innerDot!.frame.center
            let              x = center.x - CGFloat(tinyDiameter + dotRadius)
            let              y = center.y - CGFloat(tinyRadius)
            let           rect = CGRect(x: x, y: y, width: CGFloat(tinyDiameter), height: CGFloat(tinyDiameter))
            let           path = ZBezierPath(ovalIn: rect)
            path.lineWidth     = CGFloat(gLineThickness * 1.2)
            path.flatness      = 0.0001

            path.fill()
        }
    }

	func drawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
        let   thickness = CGFloat(gLineThickness)
		var        path = ZBezierPath()

		if  parameters.isReveal {
			let toRight = parameters.pointRight
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

		if  count > 0,
			let    dot = innerDot {
			let  frame = dot.frame.offsetBy(dx: -0.1, dy: -0.1)
			let  color = parameters.isDrop ? gActiveColor : parameters.color
			let radius = ((Double(frame.size.height) * gLineThickness / 24.0) + 0.4)

			drawTinyDots(surrounding: frame, count: parameters.childCount, radius: radius, color: color)
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

    func drawTinyBookmarkDot(in iDirtyRect: CGRect) {
        let     inset = CGFloat(innerDotHeight / 3.0)
        let      path = ZBezierPath(ovalIn: iDirtyRect.insetEquallyBy(inset))
        path.flatness = 0.0001

        path.fill()
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

	struct  ZDotParameters {
		var childCount : Int             = 0
		var isDrop     : Bool            = false
		var filled     : Bool            = false
		var isReveal   : Bool            = false
		var notInMap   : Bool            = false
		var isInTrash  : Bool            = false
		var isBookmark : Bool            = false
		var showAccess : Bool            = false
		var pointRight : Bool            = false
		var traitType  : String          = ""
		var fill       : ZColor          = kWhiteColor
		var color      : ZColor          = kBlackColor
		var accessType : ZDecorationType = .vertical
	}

	func drawInnerDot(_ iDirtyRect: CGRect, _ parameters: ZDotParameters) {
		let fill = parameters.filled ? gBackgroundColor : parameters.color

		parameters.color.setStroke()
		parameters.fill .setFill()

		// //////
		// DOT //
		// //////

		if  !parameters.isDrop { // so when cursor leaves window, the should-be-invisible reveal dot will indeed disappear
			drawMainDot(in: iDirtyRect, using: parameters)
		}

		if  parameters.isReveal {
			if  parameters.isBookmark {

				// //////////////////
				// TINY CENTER DOT //
				// //////////////////

				gBackgroundColor.setFill()
				drawTinyBookmarkDot(in: iDirtyRect)
			} else if parameters.traitType != "" {

				// //////////////////
				// TRAIT INDICATOR //
				// //////////////////

				drawTraitIndicator(for: parameters.traitType, isFilled: parameters.filled, color: fill, in: iDirtyRect)
			}
		} else if parameters.showAccess {

			// ///////////////////////////
			// WRITE-ACCESS DECORATIONS //
			// ///////////////////////////

			fill.setFill()
			drawWriteAccessDecoration(of: parameters.accessType, in: iDirtyRect)
		}
	}

	func drawOuterDot(_ iDirtyRect: CGRect, _ parameters: ZDotParameters) {

		// /////////////////////////////
		// MOSTLY INVISIBLE OUTER DOT //
		// /////////////////////////////

		if  parameters.isReveal {

			// /////////////////////
			// TINY COUNTER BEADS //
			// /////////////////////

			drawTinyCountDots(iDirtyRect, parameters: parameters)
		} else if parameters.notInMap && !parameters.isInTrash {

			// ////////////////////////////////
			// HIGHLIGHT OF CURRENT FAVORITE //
			// ////////////////////////////////

			parameters.color.withAlphaComponent(0.7).setFill()
			drawFavoritesHighlight(in: iDirtyRect)
		}
	}

	var drawingParameters: ZDotParameters {
		let zone              = widgetZone
		let traitKeys         = zone?.traitKeys ?? []
		var parameters        = ZDotParameters()

		parameters.isDrop     = zone == gDragDropZone
		parameters.accessType = zone?.directAccess == .eProgenyWritable ? ZDecorationType.sideDot : ZDecorationType.vertical
		parameters.notInMap   = zone?.isNotInMap            ?? false
		parameters.isInTrash  = zone?.isInTrash             ?? false
		parameters.isBookmark = zone?.isBookmark            ?? false
		parameters.showAccess = zone?.hasAccessDecoration   ?? false
		parameters.pointRight = widgetZone?.showingChildren ?? true
		parameters.color      = gColorfulMode ? zone?.color ?? gDefaultTextColor : gDefaultTextColor
		parameters.childCount = ((gCountsMode == .progeny) ? zone?.progenyCount : zone?.indirectCount) ?? 0
		parameters.traitType  = (traitKeys.count < 1) ? "" : traitKeys[0]
		parameters.filled     = isFilled
		parameters.fill       = isFilled ? parameters.color.lighter(by: 2.5) : gBackgroundColor
		parameters.isReveal   = isReveal

		return parameters
	}

    override func draw(_ iDirtyRect: CGRect) {
        super.draw(iDirtyRect)
		let parameters = drawingParameters

		if  isVisible(iDirtyRect) {
			if  isInnerDot {
				drawInnerDot(iDirtyRect, parameters)
			} else if  let  zone = widgetZone, innerDot != nil, gCountsMode == .dots, (!zone.showingChildren || zone.isBookmark) {
				drawOuterDot(iDirtyRect, parameters)
			}
		}
    }

}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}
