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


    var    dragStart: CGPoint? = nil
    var       widget: ZoneWidget?
    var     innerDot: ZoneDot?
    var     isToggle: Bool = true
    var   isInnerDot: Bool = false
    var   widgetZone: Zone?
    var isDragTarget: Bool { return widgetZone == gSelectionManager.dragDropZone }


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
            let isIndex = gSelectionManager.dragDropIndices?.contains(index)
            let  isDrop = widgetZone?.parentZone == gSelectionManager.dragDropZone

            if isDrop && isIndex! {
                return true
            }
        }

        return false
    }


    func drawTinyDots(_ dirtyRect: CGRect) {
        if  isToggle,     let zone = widgetZone, innerDot != nil, gCountsMode == .dots, (!zone.showChildren || zone.isBookmark) {
            var              count = zone.fetchableCount

            if  count == 0 {
                count = zone.count
            }

            if  count > 0 {
                let     startAngle = Double(0)
                let incrementAngle = Double.pi / Double(count)
                let         center = innerDot!.frame.center
                let      dotRadius = gDotHeight / 2.0
                let     tinyRadius =  dotRadius * gLineThickness / 12.0 + 0.7
                let   tinyDiameter = tinyRadius * 2.0
                let    orbitRadius = CGFloat(dotRadius + tinyRadius * 1.2)

                for index in 1 ... count {
                    let  increment = Double(index * 2 - 1)
                    let      angle = startAngle - incrementAngle * increment // positive means counterclockwise in osx (clockwise in ios)
                    let          x = center.x + orbitRadius * CGFloat(cos(angle)) - CGFloat(tinyRadius)
                    let          y = center.y + orbitRadius * CGFloat(sin(angle)) - CGFloat(tinyRadius)
                    let       rect = CGRect(x: x, y: y, width: CGFloat(tinyDiameter), height: CGFloat(tinyDiameter))
                    let       path = ZBezierPath(ovalIn: rect)
                    let asBookmark = (zone.isBookmark || zone.isRootOfFavorites)
                    let      color = isDragTarget ? gDragTargetsColor : asBookmark  ? gBookmarkColor : gZoneColor

                    color.setFill()
                    path.flatness = 0.0001
                    path.fill()
                }
            }
        }
    }


    override func draw(_ dirtyRect: CGRect) {
        super  .draw(dirtyRect)
        drawTinyDots(dirtyRect)

        if  let            zone = widgetZone, isInnerDot, let mode = zone.storageMode {
            let  showAsBookmark = zone.isBookmark || zone.isRootOfFavorites
            isHidden            = isToggle && ((!zone.hasChildren             && !showAsBookmark && !isDragTarget) || (mode == .favorites && !zone.isRootOfFavorites))
            let shouldHighlight = isToggle    ? (zone.indicateChildren        || zone.isBookmark ||  isDragTarget) : zone.isGrabbed // not highlight when editing
            let     strokeColor = isToggle && isDragTarget ? gDragTargetsColor :  showAsBookmark  ? gBookmarkColor : gZoneColor
            let       fillColor = shouldHighlight ? strokeColor : gBackgroundColor
            let       thickness = CGFloat(gLineThickness)
            let            path = ZBezierPath(ovalIn: dirtyRect.insetBy(dx: thickness, dy: thickness))

            fillColor.setFill()
            strokeColor.setStroke()
            path.lineWidth = thickness * 2.0
            path.flatness = 0.0001
            path.stroke()
            path.fill()
        }
    }


    func setupForWidget(_ iWidget: ZoneWidget, asToggle: Bool) {
        widgetZone = iWidget.widgetZone
        isToggle   = asToggle
        widget     = iWidget

        if isInnerDot {
            snp.makeConstraints { (make: ConstraintMaker) in
                let width = CGFloat(asToggle ? gDotHeight : gDotWidth)
                let  size = CGSize(width: width, height: CGFloat(gDotHeight))

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
                make.size.equalTo(CGSize(width: gFingerBreadth, height: gFingerBreadth))
                make.center.equalTo(innerDot!)
            }
        }

        #if os(iOS)
        backgroundColor = ZColor.clear
        #endif

        updateConstraints()
        setNeedsDisplay()
    }
}
