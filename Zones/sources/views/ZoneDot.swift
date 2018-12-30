//
//  ZoneDot.swift
//  Thoughtful
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
        var isHidden = false
        if  let zone = widgetZone, isInnerDot, isReveal {
            isHidden = !zone.canTravel && zone.count == 0 && zone.fetchableCount == 0 && !isDragDrop
        }
        
        return !isHidden
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

            innerDot!.setupForWidget(iWidget, asReveal: isReveal)
            snp.removeConstraints()
            snp.makeConstraints { make in
                var   width = !isReveal && dragDotIsHidden ? CGFloat(0.0) : (gGenericOffset.width * 2.0) - (gGenericOffset.height / 6.0) - 42.0 + innerDotWidth
                let  height = innerDotHeight + 5.0 + (gGenericOffset.height * 3.0)

                if !iWidget.isInMain {
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


    func drawTinyCountDots(_ iDirtyRect: CGRect) {
        if  let    zone = widgetZone, innerDot != nil, gCountsMode == .dots, (!zone.showingChildren || zone.isBookmark) {
            var   count = (gCountsMode == .progeny) ? zone.progenyCount : zone.indirectCount
            var aHollow = false
            var bHollow = false
            var   scale = 0.0

            while count > 100 {
                count   = (count + 5) / 10
                scale   = 1.0

                if  bHollow {
                    aHollow = true
                } else {
                    bHollow = true
                }
            }

            if  count > 0 {
                let         aCount = count % 10
                let         bCount = count / 10
                let     fullCircle = Double.pi * 2.0
                let      dotRadius = Double(innerDotHeight / 2.0)
                let        aRadius = ((dotRadius * gLineThickness / 12.0) + 0.4) * (1.25 ** scale)
                let          frame = innerDot!.frame.offsetBy(dx: -0.1, dy: -0.1)
                let         center = frame.center
                let color: ZColor? = isDragDrop ? gRubberbandColor : zone.color

                let closure: IntBooleanClosure = { (iCount, isB) in
                    let             oneSet = (isB ? aCount : bCount) == 0
                    if  iCount             > 0 {
                        let         isEven = iCount % 2 == 0
                        let incrementAngle = fullCircle / (oneSet ? 1.0 : 2.0) / Double(iCount)
                        for index in 0 ... iCount - 1 {
                            let  increment = Double(index) + ((isEven && oneSet) ? 0.0 : 0.5)
                            let startAngle = fullCircle / 4.0 * (oneSet ? isEven ? 0.0 : 2.0 : isB ? 1.0 : 3.0)
                            let      angle = startAngle + incrementAngle * increment // positive means counterclockwise in osx (clockwise in ios)
                            let     radius = CGFloat(dotRadius + aRadius * (isB ? 2.0 : 1.6))
                            let     offset = aRadius * (isB ? 2.1 : 1.13)
                            let  offCenter = CGPoint(x: center.x - CGFloat(offset), y: center.y - CGFloat(offset))
                            let          x = offCenter.x + (radius * CGFloat(cos(angle)))
                            let          y = offCenter.y + (radius * CGFloat(sin(angle)))
                            let   diameter = CGFloat((isB ? 4.0 : 2.5) * aRadius)
                            let       rect = CGRect(x: x, y: y, width: diameter, height: diameter)
                            let       path = ZBezierPath(ovalIn: rect)
                            path.lineWidth = CGFloat(gLineThickness)
                            path .flatness = 0.0001

                            if  aHollow || (isB && bHollow) {
                                color?.setStroke()
                                path.stroke()
                            } else {
                                color?.setFill()
                                path.fill()
                            }
                        }
                    }
                }

                closure(aCount, false)
                closure(bCount, true)
            }
        }
    }


    func drawWriteAccessDecoration(of type: ZDecorationType, in iDirtyRect: CGRect) {
        let     ratio = (widget?.isInMain ?? true) ? 1.0 : kFavoritesReduction
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
            let isInMain = widget?.isInMain ?? true
            let    ratio = CGFloat(isInMain ? 1.0 : Double(kFavoritesReduction))
            let     size = CGFloat(gDotHeight - 2.0) * ratio
            let     font = NSFont.boldSystemFont(ofSize: size)
            let   height = string.heightForFont(font, options: .usesDeviceMetrics) + (isInMain ? 1.0 : -2.5)
            let   xDelta = size / 3.3
            let   yDelta = ((height - iDirtyRect.height) / CGFloat(3.8))
            let     rect = iDirtyRect.insetBy(dx: xDelta, dy: yDelta)
            let    color = isFilled ? gBackgroundColor : iZone.color

            string.draw(in: rect, withAttributes: convertToOptionalNSAttributedStringKeyDictionary([convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor) : color, convertFromNSAttributedStringKey(NSAttributedString.Key.font): font]))

            return
        }
    }


    override func draw(_ iDirtyRect: CGRect) {
        super.draw(iDirtyRect)

        if  let              zone = widgetZone, isVisible(iDirtyRect) {
            let isCurrentFavorite = zone.isCurrentFavorite

            if  revealDotIsVisible {
                if  isInnerDot {
                    let childlessTraveller = zone.canTravel && zone.count == 0
                    let        dotIsFilled = isReveal ? (!zone.showingChildren || childlessTraveller || isDragDrop) : (zone.isGrabbed || isCurrentFavorite)
                    let        strokeColor = isReveal && isDragDrop ?  gRubberbandColor : zone.color
                    var          fillColor = dotIsFilled ? strokeColor.lighter(by: 3.0) : gBackgroundColor

                    /////////
                    // DOT //
                    /////////

                    fillColor.setFill()
                    strokeColor.setStroke()
                    drawMainDot(in: iDirtyRect)

                    if  isReveal {
                        if  zone.isBookmark {

                            /////////////////////
                            // TINY CENTER DOT //
                            /////////////////////

                            gBackgroundColor.setFill()
                            drawTinyBookmarkDot(in: iDirtyRect)
                        } else if zone.canTravel {

                            /////////////////////
                            // TRAIT INDICATOR //
                            /////////////////////

                            drawTraitIndicator(for: zone, isFilled: dotIsFilled, in: iDirtyRect)
                        }
                    } else if zone.hasAccessDecoration {
                        let  type = zone.directAccess == .eProgenyWritable ? ZDecorationType.sideDot : ZDecorationType.vertical
                        fillColor = dotIsFilled ? gBackgroundColor : strokeColor

                        //////////////////////////////
                        // WRITE-ACCESS DECORATIONS //
                        //////////////////////////////

                        fillColor.setFill()
                        drawWriteAccessDecoration(of: type, in: iDirtyRect)
                    }

                } else {

                    ////////////////////////////////
                    // MOSTLY INVISIBLE OUTER DOT //
                    ////////////////////////////////

                    if isReveal {

                        ///////////////////////
                        // TINY COUNTER DOTS //
                        ///////////////////////

                        // addBorderRelative(thickness: 1.0, radius: 0.5, color: ZColor.red.cgColor)
                        drawTinyCountDots(iDirtyRect)
                    } else if isCurrentFavorite {

                        ///////////////////////////////////
                        // HIGHLIGHT OF CURRENT FAVORITE //
                        ///////////////////////////////////

                        zone.color.withAlphaComponent(0.7).setFill()
                        drawFavoritesHighlight(in: iDirtyRect)
                    }
                }
            }
        }
    }

}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}
