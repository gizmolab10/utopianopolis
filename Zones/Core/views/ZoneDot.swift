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


    var          toggle: Bool!
    var        innerDot: ZoneDot?
    var      isOuterDot: Bool = true
    var shouldHighlight: Bool = false


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
            // addBorder(thickness: lineThicknes, radius: userTouchLength / 2.0, color: ZColor.red.cgColor)
            snp.makeConstraints { (make) in
                make.size.equalTo(CGSize(width: userTouchLength, height: userTouchLength))
                make.center.equalTo(innerDot!)
            }
        } else {
            let radius:    CGFloat = dotLength * 0.5 * (asToggle ? 1.0 : 0.65)
            shouldHighlight        = asToggle ? !widgetZone.showChildren : selectionManager.isGrabbed(zone: widgetZone)
            zlayer.backgroundColor = (shouldHighlight ? lineColor : unselectedColor).cgColor

            addBorder(thickness: lineThicknes, radius: radius, color: lineColor.cgColor)
            snp.makeConstraints { (make) in
                let width: CGFloat = asToggle ? dotLength : dotLength * 0.65

                make.size.equalTo(CGSize(width: width, height: dotLength))
            }
        }

        updateConstraints()
    }


    func gestureEvent(_ sender: ZGestureRecognizer?) {
        let widget: ZoneWidget = superview as! ZoneWidget

        toConsole("dot")

        if let zone = widget.widgetZone {
            if toggle == true {
                editingManager.toggleChildrenVisibility(zone)
            } else {
                selectionManager.deselect()
                selectionManager.currentlyGrabbedZones = [zone]
                controllersManager.updateToClosures(zone, regarding: .datum)
            }
        }
    }
}
