//
//  ZoneDot.swift
//  Zones
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
    

    weak var widgetZone: Zone?
    weak var     widget: ZoneWidget?
    var        innerDot: ZoneDot?
    var        isToggle: Bool     = true
    var       dragStart: CGPoint? = nil
    var      isInnerDot: Bool     = false
    var    isDragTarget: Bool { return widgetZone == gDragDropZone }
    var isDragDotHidden: Bool { return widget?.widgetZone?.onlyShowToggleDot ?? true }


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
        if  let   index = widgetZone?.siblingIndex, !isToggle {
            let isIndex = gDragDropIndices?.contains(index)
            let  isDrop = widgetZone?.parentZone == gDragDropZone

            if isDrop && isIndex! {
                return true
            }
        }

        return false
    }


    var isHiddenToggleDot: Bool {
        if  let zone = widgetZone, isInnerDot, isToggle, let mode = zone.storageMode {

            return (!zone.isBookmark && !zone.isHyperlink && zone.fetchableCount == 0 && zone.count == 0 && !isDragTarget)
                || (!zone.isRootOfFavorites && mode == .favoritesMode)
        }
        
        return false
    }


    // MARK:- initialization
    // MARK:-

    var         ratio:  CGFloat { return widgetZone?.isInFavorites ?? false ? gReductionRatio : 1.0 }
    var innerDotWidth:  CGFloat { return CGFloat(isToggle ? gDotHeight : isDragDotHidden ? 0.0 : gDotWidth) * ratio }
    var innerDotHeight: CGFloat { return CGFloat(gDotHeight * Double(ratio)) }


    func setupForWidget(_ iWidget: ZoneWidget, asToggle: Bool) {
        widgetZone = iWidget.widgetZone
        isToggle   = asToggle
        widget     = iWidget

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

            innerDot!.setupForWidget(iWidget, asToggle: isToggle)
            snp.removeConstraints()
            snp.makeConstraints { make in
                var   width = !isToggle && isDragDotHidden ? CGFloat(0.0) : (gGenericOffset.width * 2.0) - (gGenericOffset.height / 6.0) - 42.0 + innerDotWidth
                let  height = innerDotHeight + 5.0 + (gGenericOffset.height * 3.0)

                if iWidget.widgetZone?.isInFavorites ?? false {
                    width  *= gReductionRatio
                }

                make.size.equalTo(CGSize(width: width, height: height))
                make.center.equalTo(innerDot!)
            }
        }

        #if os(iOS)
            backgroundColor = gClearColor
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


    func drawTinyDots(_ dirtyRect: CGRect) {
        if  let  zone  = widgetZone, innerDot != nil, gCountsMode == .dots, (!zone.showChildren || zone.isBookmark) {
            var count  = zone.fetchableCount

            if  count == 0 {
                count  = zone.count
            }

            if  count > 1 {
                let      dotRadius = Double(innerDotHeight / 2.0)
                let     tinyRadius =  dotRadius * gLineThickness / 12.0 + 0.7
                let   tinyDiameter = tinyRadius * 2.0
                let         center = innerDot!.frame.center
                let      offCenter = CGPoint(x: center.x - CGFloat(tinyRadius), y: center.y - CGFloat(tinyRadius))
                var color: ZColor? = nil
                var rect:  CGRect? = nil
                let     startAngle = Double(0)
                let incrementAngle = Double.pi / Double(count)
                let    orbitRadius = CGFloat(dotRadius + tinyRadius * 1.2)

                for index in 1 ... count {
                    let  increment = Double(index * 2 - 1)
                    let      angle = startAngle - incrementAngle * increment // positive means counterclockwise in osx (clockwise in ios)
                    let          x = offCenter.x + orbitRadius * CGFloat(cos(angle))
                    let          y = offCenter.y + orbitRadius * CGFloat(sin(angle))
                    rect           = CGRect(x: x, y: y, width: CGFloat(tinyDiameter), height: CGFloat(tinyDiameter))
                    color          = isDragTarget ? gRubberbandColor : zone.color
                    let       path = ZBezierPath(ovalIn: rect!)
                    path .flatness = 0.0001

                    color?.setFill()
                    path.fill()
                }
            }
        }
    }


    func drawAccessDecoration(of type: ZDecorationType, for zone: Zone, in dirtyRect: CGRect) {
        let     ratio = zone.isInFavorites ? gReductionRatio : 1.0
        var thickness = CGFloat(gLineThickness + 0.1) * ratio
        var      path = ZBezierPath(rect: CGRect.zero)
        var      rect = CGRect.zero

        switch type {
        case .vertical:
            rect      = CGRect(origin: CGPoint(x: dirtyRect.midX - (thickness / 2.0), y: dirtyRect.minY),                   size: CGSize(width: thickness, height: dirtyRect.size.height))
            path      = ZBezierPath(rect: rect)
        case .sideDot:
            thickness = (thickness + 2.5) * dirtyRect.size.height / 12.0
            rect      = CGRect(origin: CGPoint(x: dirtyRect.maxX -  thickness - 1.0,   y: dirtyRect.midY - thickness / 2.0), size: CGSize(width: thickness, height: thickness))
            path      = ZBezierPath(ovalIn: rect)
        }

        path.fill()
    }


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        if  let                zone = widgetZone, isVisible(dirtyRect) {
            let highlightAsFavorite = zone.isCurrentFavorite

            if !isHiddenToggleDot {
                if isInnerDot {
                    let isChildlessHyperlink = zone.isHyperlink && zone.progenyCount == 0
                    let shouldHighlight = isToggle ? (!zone.showChildren || zone.isBookmark || isChildlessHyperlink || isDragTarget) : zone.isGrabbed || highlightAsFavorite // not highlight when editing
                    let     strokeColor = isToggle && isDragTarget ? gRubberbandColor : zone.color
                    var       fillColor = shouldHighlight ? strokeColor : gBackgroundColor
                    let       thickness = CGFloat(gLineThickness)
                    var            path = ZBezierPath(ovalIn: dirtyRect.insetBy(dx: thickness, dy: thickness))

                    path     .lineWidth = thickness * 2.0
                    path      .flatness = 0.0001

                    fillColor.setFill()
                    strokeColor.setStroke()
                    path.stroke()
                    path.fill()

                    if isToggle {
                        if  zone.isBookmark || isChildlessHyperlink { // draw tiny bookmark dot inside toggle dot
                            let     inset = CGFloat(innerDotHeight / 3.0)
                            path          = ZBezierPath(ovalIn: dirtyRect.insetBy(dx: inset, dy: inset))
                            path.flatness = 0.0001

                            gBackgroundColor.setFill()
                            path.fill()
                        }
                    } else if                       zone.hasAccessDecoration {
                        let type: ZDecorationType = zone.directChildrenWritable ? .sideDot : .vertical
                        fillColor                 = shouldHighlight ? gBackgroundColor : strokeColor

                        fillColor.setFill()
                        drawAccessDecoration(of: type, for: zone, in: dirtyRect)
                    }
                } else if isToggle {
                    // addBorderRelative(thickness: 1.0, radius: 0.5, color: ZColor.red.cgColor)
                    drawTinyDots(dirtyRect)
                } else if highlightAsFavorite {
                    let     yInset = (dirtyRect.size.height - CGFloat(gDotHeight)) / 2.0 - 2.0
                    let     xInset = (dirtyRect.size.width  - CGFloat(gDotWidth )) / 2.0 - 2.0
                    let       path = ZBezierPath(ovalIn: dirtyRect.offsetBy(dx: 0.0, dy: 0.5).insetBy(dx: xInset, dy: yInset))
                    path.lineWidth = CGFloat(gDotWidth) / 5.0
                    path.flatness  = 0.0001

                    zone.color.withAlphaComponent(0.7).setStroke()
                    path.stroke()
                }
            }
        }
    }

}
