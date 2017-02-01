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
    var doubleClicker: ZGestureRecognizer?
    var singleClicker: ZGestureRecognizer?


    var width: CGFloat {
        get {
            return innerDot!.bounds.width
        }
    }


    override func draw(_ dirtyRect: CGRect) {
        if isInnerDot, let zone = widgetZone, let record = zone.record {
            let      isBookmark = zone.isBookmark || record.recordID.recordName == favoritesRootNameKey
            let   selectedColor = isBookmark ? gBookmarkColor : gZoneColor
            let shouldHighlight = isToggle ? (!(zone.showChildren) || isBookmark) : zone.isSelected
            let       fillColor = shouldHighlight ? selectedColor : ZColor.clear
            let       thickness = CGFloat(gLineThickness)
            let            path = ZBezierPath(ovalIn: dirtyRect.insetBy(dx: thickness, dy: thickness))

            fillColor.setFill()
            selectedColor.setStroke()
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
            if innerDot == nil {
                innerDot  = ZoneDot()

                addSubview(innerDot!)
            }

            clearGestures()

            doubleClicker          = createGestureRecognizer(self, action: #selector(ZoneDot.twoClicks), clicksRequired: 2)
            singleClicker          = createGestureRecognizer(self, action: #selector(ZoneDot.oneClick),  clicksRequired: 1)
            innerDot?.isInnerDot   = true

            innerDot?.setupForZone(zone, asToggle: isToggle)
            snp.makeConstraints { (make: ConstraintMaker) in
                make.size.equalTo(CGSize(width: gFingerBreadth, height: gFingerBreadth))
                make.center.equalTo(innerDot!)
            }
        }

        updateConstraints()
    }


    func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: ZGestureRecognizer) -> Bool {
        return gestureRecognizer == singleClicker && otherGestureRecognizer == doubleClicker
    }
    

    func twoClicks(_ iGesture: ZGestureRecognizer?) {
        if let widget: ZoneWidget = superview as? ZoneWidget, let zone = widget.widgetZone {
            if isToggle {
                gEditingManager.toggleDotActionOnZone(zone, recursively: true)
            } else {
                gEditingManager.focusOnZone(zone)
            }
        }
    }


    func oneClick(_ iGesture: ZGestureRecognizer?) {
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
}
