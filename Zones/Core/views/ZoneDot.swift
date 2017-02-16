//
//  ZoneDot.swift
//  Zones
//
//  Created by Jonathan Sand on 10/27/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneDot: ZView, ZGestureRecognizerDelegate {


    var      innerDot: ZoneDot?
    var    isInnerDot: Bool = false
    var      isToggle: Bool = true
    var    widgetZone: Zone?
    var   dragGesture: ZGestureRecognizer?
    var doubleGesture: ZGestureRecognizer?
    var singleGesture: ZGestureRecognizer?


    var width: CGFloat {
        get {
            return innerDot!.bounds.width
        }
    }


    override func draw(_ dirtyRect: CGRect) {
        if isInnerDot, let zone = widgetZone {
            let      isBookmark = zone.isBookmark || zone.isRootOfFavorites
            let    isDragTarget = gSelectionManager.currentDragTarget == zone
            let     strokeColor = isBookmark ? gBookmarkColor : gZoneColor
            let shouldHighlight = isToggle ? (!(zone.showChildren) || isBookmark) : zone.isSelected || isDragTarget
            let       fillColor = shouldHighlight ? isDragTarget ? ZColor.red : strokeColor : ZColor.clear
            let       thickness = CGFloat(gLineThickness)
            let            path = ZBezierPath(ovalIn: dirtyRect.insetBy(dx: thickness, dy: thickness))

            fillColor.setFill()
            strokeColor.setStroke()
            path.lineWidth = thickness
            path.flatness = 0.0001
            path.stroke()
            path.fill()
        }
    }


    func setupForZone(_ zone: Zone, asToggle: Bool) {
        isToggle   = asToggle
        widgetZone = zone

        if isInnerDot {
            snp.makeConstraints { (make: ConstraintMaker) in
                let width = CGFloat(asToggle ? gDotHeight : gDotHeight * 0.75)
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

            clearGestures()

            if !isToggle {
                dragGesture          =  createDragGestureRecognizer(self, action: #selector(ZoneDot.dragEvent))
                doubleGesture        = createPointGestureRecognizer(self, action: #selector(ZoneDot.doubleEvent), clicksRequired: 2)
            }

            singleGesture            = createPointGestureRecognizer(self, action: #selector(ZoneDot.singleEvent), clicksRequired: 1)

            innerDot?.setupForZone(zone, asToggle: isToggle)
            snp.makeConstraints { (make: ConstraintMaker) in
                make.size.equalTo(CGSize(width: gFingerBreadth, height: gFingerBreadth))
                make.center.equalTo(innerDot!)
            }
        }

        #if os(iOS)
        backgroundColor = ZColor.clear
        #endif

        updateConstraints()
    }


    func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: ZGestureRecognizer) -> Bool {
        return isToggle ? false : gestureRecognizer == singleGesture && otherGestureRecognizer == doubleGesture
    }
    

    func doubleEvent(_ iGesture: ZGestureRecognizer?) {
        if let widget: ZoneWidget = superview as? ZoneWidget, let zone = widget.widgetZone {
            if isToggle {
                gEditingManager.toggleDotActionOnZone(zone, recursively: true)
            } else {
                gEditingManager.focusOnZone(zone)
            }
        }
    }


    func singleEvent(_ iGesture: ZGestureRecognizer?) {
        if let widget: ZoneWidget = superview as? ZoneWidget, let zone = widget.widgetZone {
            if isToggle {
                gEditingManager.toggleDotActionOnZone(zone, recursively: false)
            } else {
                gSelectionManager.deselect()
                zone.grab()
                signalFor(zone, regarding: .datum)
            }
        }
    }


    func dragEvent(_ iGesture: ZGestureRecognizer?) { editorController?.handleDragEvent(iGesture) }
}
