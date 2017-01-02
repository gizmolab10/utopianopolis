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


class ZoneDot: ZView, NSGestureRecognizerDelegate {


    var      innerDot: ZoneDot?
    var    isInnerDot: Bool = false
    var    isRevealer: Bool = true
    var  douleClicker: NSGestureRecognizer?
    var singleClicker: NSGestureRecognizer?


    func setupForZone(_ widgetZone: Zone, asRevealer: Bool) {
        isRevealer                 = asRevealer

        if isInnerDot {
            let             radius = dotHeight / (isRevealer ? 2.0 : 3.0)
            let      selectedColor = widgetZone.isBookmark ? bookmarkColor : lineColor
            let    shouldHighlight = isRevealer ? !widgetZone.showChildren || widgetZone.isBookmark : selectionManager.isGrabbed(widgetZone)
            zlayer.backgroundColor = (shouldHighlight ? selectedColor : unselectedColor).cgColor

            addBorder(thickness: CGFloat(lineThicknes), radius: CGFloat(radius), color: selectedColor.cgColor)
            snp.makeConstraints { (make: ConstraintMaker) in
                let          width = CGFloat(asRevealer ? dotHeight : dotHeight * 0.65)
                let           size = CGSize(width: width, height: CGFloat(dotHeight))

                make.size.equalTo(size)
            }
        } else {
            if innerDot == nil {
                innerDot           = ZoneDot()

                addSubview(innerDot!)
            }

            clearGestures()

            singleClicker          = createGestureRecognizer(self, action: #selector(ZoneDot.oneClick),  clicksRequired: 1)
            douleClicker           = createGestureRecognizer(self, action: #selector(ZoneDot.twoClicks), clicksRequired: 2)
            zlayer.backgroundColor = ZColor.clear.cgColor
            innerDot?.isInnerDot   = true

            innerDot?.setupForZone(widgetZone, asRevealer: isRevealer)
            // addBorder(thickness: lineThicknes, radius: fingerBreadth / 2.0, color: ZColor.red.cgColor)
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
            if isRevealer {
                editingManager.revealerDotActionOnZone(zone, extreme: true)
            } else {
                editingManager.focusOnZone(zone)
            }
        }
    }


    func oneClick(_ iGesture: ZGestureRecognizer?) {
        if let widget: ZoneWidget = superview as? ZoneWidget, let zone = widget.widgetZone {
            if isRevealer {
                editingManager.revealerDotActionOnZone(zone, extreme: false)
            } else {
                selectionManager.deselect()
                selectionManager.grab(zone)
                signalFor(zone, regarding: .datum)
            }
        }
    }
}
