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


    var     toggle: Bool!
    var   innerDot: ZoneDot?
    var isOuterDot: Bool = true


    func setupForZone(_ widgetZone: Zone, asToggle: Bool) {
        toggle                       = asToggle

        if isOuterDot {
            zlayer.backgroundColor   = ZColor.clear.cgColor

            if innerDot == nil {
                innerDot             = ZoneDot()
                innerDot?.isOuterDot = false
            }

            setupGestures(self, action: #selector(ZoneDot.gestureEvent))
            self.addSubview(innerDot!)
            innerDot?.setupForZone(widgetZone, asToggle: asToggle)
            // addBorder(thickness: lineThicknes, radius: fingerBreadth / 2.0, color: ZColor.red.cgColor)
            snp.makeConstraints { (make: ConstraintMaker) in
                make.size.equalTo(CGSize(width: fingerBreadth, height: fingerBreadth))
                make.center.equalTo(innerDot!)
            }
        } else {
            let             radius = dotHeight / (asToggle ? 2.0 : 3.0)
            let      selectedColor = widgetZone.isBookmark ? bookmarkColor : lineColor
            let    shouldHighlight = asToggle ? !widgetZone.showChildren || widgetZone.isBookmark : selectionManager.isGrabbed(widgetZone)
            zlayer.backgroundColor = (shouldHighlight ? selectedColor : unselectedColor).cgColor

            addBorder(thickness: CGFloat(lineThicknes), radius: CGFloat(radius), color: selectedColor.cgColor)
            snp.makeConstraints { (make: ConstraintMaker) in
                let          width = CGFloat(asToggle ? dotHeight : dotHeight * 0.65)
                let           size = CGSize(width: width, height: CGFloat(dotHeight))

                make.size.equalTo(size)
            }
        }

        updateConstraints()
    }


    func gestureEvent(_ sender: ZGestureRecognizer?) {
        let widget: ZoneWidget = superview as! ZoneWidget

        toConsole("dot")

        if let zone = widget.widgetZone {
            if toggle == true {
                editingManager.revealerDotActionOnZone(zone)
            } else {
                selectionManager.deselect()
                selectionManager.grab(zone)
                signalFor(zone, regarding: .datum)
            }
        }
    }
}
