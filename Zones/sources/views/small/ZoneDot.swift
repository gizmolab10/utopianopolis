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


class ZoneDot: ZView, ZGestureRecognizerDelegate {


    // MARK:- properties
    // MARK:-
    

    weak var     widget: ZoneWidget?
    var        innerDot: ZoneDot?
    var       dragStart: CGPoint?
    var        isReveal:  Bool = true
    var      isInnerDot:  Bool = false
    var      isDragDrop:  Bool { return widgetZone == gDragDropZone }
    var      widgetZone: Zone? { return widget?.widgetZone }
    var dragDotIsHidden:  Bool { return widgetZone?.dragDotIsHidden ?? true }


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


    var revealDotIsVisible: Bool {
        var isVisible = true
        if  let  zone = widgetZone, isReveal {
            isVisible = isDragDrop || zone.canTravel || zone.count > 0
        }
        
        return isVisible
    }


    // MARK:- initialization
    // MARK:-


    var         ratio:  CGFloat { return widget?.ratio ?? 1.0 }
    var innerDotWidth:  CGFloat { return ratio * CGFloat(isReveal ? gDotHeight : dragDotIsHidden ? 0.0 : gDotWidth) }
    var innerDotHeight: CGFloat { return ratio * CGFloat(gDotHeight) }


    func setupForWidget(_ iWidget: ZoneWidget, asReveal: Bool) {
        isReveal = asReveal
        widget   = iWidget
		
        if isInnerDot {
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

                if !iWidget.isInMap {
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
    }


    // MARK:- draw
    // MARK:-


    enum ZDecorationType: Int {
        case vertical
        case sideDot
    }


    func isVisible(_ rect: CGRect) -> Bool {
        return window?.contentView?.bounds.intersects(rect) ?? false
    }


    func drawFavoritesHighlight(in iDirtyRect: CGRect) {
        if  let          zone  = widgetZone, innerDot != nil, !zone.isRootOfFavorites {
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


    func drawMainDot(in iDirtyRect: CGRect) {
        let  thickness = CGFloat(gLineThickness)
        let       path = ZBezierPath(ovalIn: iDirtyRect.insetBy(dx: thickness, dy: thickness))
        path.lineWidth = thickness * 2.0
        path .flatness = 0.0001

        path.stroke()
        path.fill()
    }


    func drawTinyCounterDots(_ iDirtyRect: CGRect) {
        if  let  zone = widgetZone, innerDot != nil, gCountsMode == .dots, (!zone.showingChildren || zone.isBookmark) {
            let count = (gCountsMode == .progeny) ? zone.progenyCount : zone.indirectCount

            if  count > 0 {
                let          frame = innerDot!.frame.offsetBy(dx: -0.1, dy: -0.1)
                let color: ZColor? = isDragDrop ? gActiveColor : zone.color
                let         radius = ((Double(frame.size.height) * gLineThickness / 24.0) + 0.4)

				drawTinyDots(surrounding: frame, objects: zone.children, radius: radius, color: color)
            }
        }
    }


    func drawWriteAccessDecoration(of type: ZDecorationType, in iDirtyRect: CGRect) {
        let     ratio = (widget?.isInMap ?? true) ? 1.0 : kFavoritesReduction
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
        let      path = ZBezierPath(ovalIn: iDirtyRect.insetBy(dx: inset, dy: inset))
        path.flatness = 0.0001

        path.fill()
    }


    func drawTraitIndicator(for iZone: Zone, isFilled: Bool, in iDirtyRect: CGRect) {
        let types = iZone.traits.keys
        for type in types {
            let   string = type.rawValue
            let inPublic = widget?.isInMap ?? true
            let    ratio = CGFloat(inPublic ? 1.0 : Double(kFavoritesReduction))
            let    width = CGFloat(gDotHeight - 2.0) * ratio
            let     font = ZFont.boldSystemFont(ofSize: width)
			let     size = string.sizeWithFont(font)
			let   height = size.height * type.heightRatio + (inPublic ? 1.0 : -2.5)
			let   xDelta = (iDirtyRect.width - size.width) / CGFloat(2.0)
			let   yDelta = (height - iDirtyRect.height) / CGFloat(4.0)
			let     rect = iDirtyRect.insetBy(dx: xDelta, dy: yDelta).offsetBy(dx: 0.0, dy: (height / 12.0) - 1)
			let    color = isFilled ? gBackgroundColor : gColorfulMode ? (iZone.color ?? gDefaultTextColor) : gDefaultTextColor

            string.draw(in: rect, withAttributes: [.foregroundColor : color, .font: font])

            return
        }
    }


    override func draw(_ iDirtyRect: CGRect) {
        super.draw(iDirtyRect)

        if  let              zone = widgetZone, isVisible(iDirtyRect) {
            let isCurrentFavorite = zone.isCurrentFavorite && !zone.isInTrash

            if  revealDotIsVisible {
                if  isInnerDot {
                    let childlessTraveller = zone.canTravel && zone.count == 0
                    let        dotIsFilled = isReveal ? (!zone.showingChildren || childlessTraveller || isDragDrop) : zone.isGrabbed
                    let        strokeColor = isReveal && isDragDrop ?  gActiveColor : zone.color
					var          fillColor = dotIsFilled ? strokeColor?.lighter(by: 2.5) : gBackgroundColor

                    // //////
                    // DOT //
                    // //////

                    fillColor?.setFill()
                    strokeColor?.setStroke()
                    drawMainDot(in: iDirtyRect)

                    if  isReveal {
                        if  zone.isBookmark {

                            // //////////////////
                            // TINY CENTER DOT //
                            // //////////////////

                            gBackgroundColor.setFill()
                            drawTinyBookmarkDot(in: iDirtyRect)
                        } else if zone.canTravel {

                            // //////////////////
                            // TRAIT INDICATOR //
                            // //////////////////

                            drawTraitIndicator(for: zone, isFilled: dotIsFilled, in: iDirtyRect)
                        }
                    } else if zone.hasAccessDecoration {
                        let  type = zone.directAccess == .eProgenyWritable ? ZDecorationType.sideDot : ZDecorationType.vertical
                        fillColor = dotIsFilled ? gBackgroundColor : strokeColor

                        // ///////////////////////////
                        // WRITE-ACCESS DECORATIONS //
                        // ///////////////////////////

                        fillColor?.setFill()
                        drawWriteAccessDecoration(of: type, in: iDirtyRect)
                    }

                } else {

                    // /////////////////////////////
                    // MOSTLY INVISIBLE OUTER DOT //
                    // /////////////////////////////

                    if isReveal {

                        // /////////////////////
                        // TINY COUNTER BEADS //
                        // /////////////////////

                        drawTinyCounterDots(iDirtyRect)
                    } else if isCurrentFavorite {

                        // ////////////////////////////////
                        // HIGHLIGHT OF CURRENT FAVORITE //
                        // ////////////////////////////////

                        zone.color?.withAlphaComponent(0.7).setFill()
                        drawFavoritesHighlight(in: iDirtyRect)
                    }
                }
            }
        }
    }

}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}
