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


    override func draw(_ dirtyRect: CGRect) {
        if isInnerDot {
            let      isBookmark = (widgetZone?.isBookmark)!
            let   selectedColor = isBookmark ? gBookmarkColor : gZoneColor
            let shouldHighlight = isToggle ? !(widgetZone?.showChildren)! || isBookmark : selectionManager.isGrabbed(widgetZone!)
            let       fillColor = shouldHighlight ? selectedColor : gBackgroundColor
            let            path = ZBezierPath(ovalIn: dirtyRect.insetBy(dx: 1.0, dy: 1.0))

            fillColor.setFill()
            selectedColor.setStroke()
            path.lineWidth = CGFloat(gLineThickness)
            path.flatness = 0.0001
            path.stroke()
        }
    }


    func setupForZone(_ zone: Zone, asToggle: Bool) {
        isToggle   = asToggle
        widgetZone = zone

        if isInnerDot {
            snp.makeConstraints { (make: ConstraintMaker) in
                let width = CGFloat(asToggle ? gDotHeight : gDotHeight * 0.65)
                let  size = CGSize(width: width, height: CGFloat(gDotHeight))

                make.size.equalTo(size)
            }
        } else {
            if innerDot == nil {
                innerDot  = ZoneDot()

                addSubview(innerDot!)
            }

            clearGestures()

            douleClicker           = createGestureRecognizer(self, action: #selector(ZoneDot.twoClicks), clicksRequired: 2)
            singleClicker          = createGestureRecognizer(self, action: #selector(ZoneDot.oneClick),  clicksRequired: 1)
            zlayer.backgroundColor = ZColor.clear.cgColor
            innerDot?.isInnerDot   = true

            innerDot?.setupForZone(zone, asToggle: isToggle)
            // addBorder(thickness: gLineThickness, radius: fingerBreadth / 2.0, color: ZColor.red.cgColor)
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
                selectionManager.grab(zone)
                signalFor(zone, regarding: .datum)
            }
        }
    }
}
