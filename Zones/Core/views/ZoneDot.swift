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


class ZoneDot: ZView {


    var   innerDot: ZoneDot?
    var isInnerDot: Bool = false
    var isRevealer: Bool = true


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

            zlayer.backgroundColor = ZColor.clear.cgColor
            innerDot?.isInnerDot   = true

            setupGestures(self, action: #selector(ZoneDot.gestureEvent))
            innerDot?.setupForZone(widgetZone, asRevealer: isRevealer)
            // addBorder(thickness: lineThicknes, radius: fingerBreadth / 2.0, color: ZColor.red.cgColor)
            snp.makeConstraints { (make: ConstraintMaker) in
                make.size.equalTo(CGSize(width: fingerBreadth, height: fingerBreadth))
                make.center.equalTo(innerDot!)
            }
        }

        updateConstraints()
    }


    func gestureEvent(_ sender: ZGestureRecognizer?) {
        let widget: ZoneWidget = superview as! ZoneWidget

        toConsole("dot")

        if let zone = widget.widgetZone {
            if isRevealer {
                editingManager.revealerDotActionOnZone(zone)
            } else {
                selectionManager.deselect()
                selectionManager.grab(zone)
                signalFor(zone, regarding: .datum)
            }
        }
    }
}
