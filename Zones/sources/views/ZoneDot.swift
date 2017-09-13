//
//  ZoneDot.swift
//  Zones
//
//  Created by Jonathan Sand on 10/27/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneDot: ZView, ZGestureRecognizerDelegate {


    // MARK:- properties
    // MARK:-
    

    var   widgetZone: Zone?
    var       widget: ZoneWidget?
    var     innerDot: ZoneDot?
    var     isToggle: Bool     = true
    var    dragStart: CGPoint? = nil
    var   isInnerDot: Bool     = false
    var  isInvisible: Bool { return widget?.widgetZone.isRootOfFavorites ?? false }
    var isDragTarget: Bool { return widgetZone == gDragDropZone }


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

            return (zone.fetchableCount == 0 && zone.count == 0 && !zone.isBookmark && !isDragTarget) || (mode == .favoritesMode && !zone.isRootOfFavorites)
        }
        
        return false
    }


    // MARK:- initialization
    // MARK:-

    var         ratio:  CGFloat { return widgetZone?.isInFavorites ?? false ? gReductionRatio : 1.0 }
    var innerDotWidth:  CGFloat { return CGFloat(isToggle ? gDotHeight : isInvisible ? 0.0 : gDotWidth) * ratio }
    var innerDotHeight: CGFloat { return CGFloat(gDotHeight * Double(ratio)) }


    func setupForWidget(_ iWidget: ZoneWidget, asToggle: Bool) {
        widgetZone = iWidget.widgetZone
        isToggle   = asToggle
        widget     = iWidget

        if isInnerDot {
            snp.makeConstraints { (make: ConstraintMaker) in
                let  size = CGSize(width: innerDotWidth, height: innerDotHeight)

                make.size.equalTo(size)
            }

            setNeedsDisplay(frame)
        } else {
            if  innerDot            == nil {
                innerDot             = ZoneDot()
                innerDot?.isInnerDot = true

                addSubview(innerDot!)
            }

            innerDot?.setupForWidget(iWidget, asToggle: isToggle)
            snp.makeConstraints { (make: ConstraintMaker) in
                let width = CGFloat(isInvisible && !isToggle ? 0.0 : gFingerBreadth)

                make.size.equalTo(CGSize(width: width, height: gFingerBreadth))
                make.center.equalTo(innerDot!)//.offset(0.5)
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
                    color          = isDragTarget ? gDragTargetsColor : zone.color
                    let       path = ZBezierPath(ovalIn: rect!)
                    path .flatness = 0.0001

                    color?.setFill()
                    path.fill()
                }
            }
        }
    }


    func isVisible(_ rect: CGRect) -> Bool {
        return window?.contentView?.bounds.intersects(rect) ?? false
    }


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        if  let                zone = widgetZone, isVisible(dirtyRect) {
            let highlightAsFavorite = zone == gFavoritesManager.currentFavorite
            isHidden                = isHiddenToggleDot

            if !isHidden {
                if isInnerDot {
                    let shouldHighlight = isToggle ? (!zone.showChildren || zone.isBookmark || isDragTarget) : zone.isGrabbed || highlightAsFavorite // not highlight when editing
                    let     strokeColor = isToggle && isDragTarget ? gDragTargetsColor : zone.color
                    let       fillColor = shouldHighlight ? strokeColor : gBackgroundColor
                    let       thickness = CGFloat(gLineThickness)
                    var            path = ZBezierPath(ovalIn: dirtyRect.insetBy(dx: thickness, dy: thickness))

                    path     .lineWidth = thickness * 2.0
                    path      .flatness = 0.0001

                    fillColor.setFill()
                    strokeColor.setStroke()
                    path.stroke()
                    path.fill()

                    if isToggle && zone.isBookmark {
                        let       inset = CGFloat(innerDotHeight / 3.0)
                        path            = ZBezierPath(ovalIn: dirtyRect.insetBy(dx: inset, dy: inset))
                        path  .flatness = 0.0001

                        gBackgroundColor.setFill()
                        path.fill()
                    }
                } else if isToggle {
                    drawTinyDots(dirtyRect)
                } else if highlightAsFavorite {
                    let     yInset = (dirtyRect.size.height - CGFloat(gDotHeight)) / 2.0 - 2.0
                    let     xInset = (dirtyRect.size.width  - CGFloat(gDotWidth )) / 2.0 - 2.0
                    let       path = ZBezierPath(ovalIn: dirtyRect.offsetBy(dx: 0.5, dy: 0.0).insetBy(dx: xInset, dy: yInset))
                    path.lineWidth = CGFloat(gDotWidth) / 5.0
                    path.flatness  = 0.0001

                    zone.color.withAlphaComponent(0.7).setStroke()
                    path.stroke()

                }
            }
        }
    }

}
