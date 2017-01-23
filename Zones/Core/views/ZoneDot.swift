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
    var  douleClicker: NSGestureRecognizer?
    var singleClicker: NSGestureRecognizer?


    var width: CGFloat {
        get {
            return innerDot!.bounds.width
        }
    }


    override func draw(_ dirtyRect: CGRect) {
        if isInnerDot && widgetZone != nil {
            let      isBookmark = widgetZone!.isBookmark
            let   selectedColor = isBookmark ? gBookmarkColor : gZoneColor
            let shouldHighlight = isToggle ? (!(widgetZone!.showChildren) || isBookmark) : widgetZone!.isSelected
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

            douleClicker           = createGestureRecognizer(self, action: #selector(ZoneDot.twoClicks), clicksRequired: 2)
            singleClicker          = createGestureRecognizer(self, action: #selector(ZoneDot.oneClick),  clicksRequired: 1)
            innerDot?.isInnerDot   = true

            innerDot?.setupForZone(zone, asToggle: isToggle)
            snp.makeConstraints { (make: ConstraintMaker) in
                make.size.equalTo(CGSize(width: fingerBreadth, height: fingerBreadth))
                make.center.equalTo(innerDot!)
            }
        }

        updateConstraints()
    }


    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: NSGestureRecognizer) -> Bool {
        return gestureRecognizer == singleClicker && otherGestureRecognizer == douleClicker
    }
    

    func twoClicks(_ iGesture: ZGestureRecognizer?) {
        if let widget: ZoneWidget = superview as? ZoneWidget, let zone = widget.widgetZone {
            if isToggle {
                editingManager.toggleDotActionOnZone(zone, recursively: true)
            } else {
                editingManager.focusOnZone(zone)
            }
        }
    }


    func oneClick(_ iGesture: ZGestureRecognizer?) {
        if let widget: ZoneWidget = superview as? ZoneWidget, let zone = widget.widgetZone {
            if isToggle {
                editingManager.toggleDotActionOnZone(zone, recursively: false)
            } else {
                selectionManager.deselect()
                zone.grab()
                signalFor(zone, regarding: .datum)
            }
        }
    }
}
