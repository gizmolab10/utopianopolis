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


let goodUserLength: CGFloat = 33.0


class ZoneDot: ZView {


    var          toggle: Bool!
    var        innerDot: ZoneDot?
    var      isOuterDot: Bool = true
    var shouldHighlight: Bool = false


    func setupForZone(_ widgetZone: Zone, asToggle: Bool) {
        toggle                       = asToggle

        if isOuterDot {
            zlayer.backgroundColor   = ZColor.clear.cgColor
            innerDot                 = ZoneDot()
            innerDot?.isOuterDot     = false
            isUserInteractionEnabled = true
            // let radius:      CGFloat = goodUserLength / 2.0

            self.addSubview(innerDot!)

            innerDot?.setupForZone(widgetZone, asToggle: asToggle)
            snp.makeConstraints { (make) in
                make.size.equalTo(CGSize(width: goodUserLength, height: goodUserLength))
                make.center.equalTo(innerDot!)
            }

            // addBorder(thickness: stateManager.dotThicknes, radius: radius, color: ZColor.red.cgColor)
        } else {
            let radius:      CGFloat = stateManager.dotLength * 0.5 * (asToggle ? 1.0 : 0.65)
            shouldHighlight          = asToggle ? !widgetZone.showChildren : zonesManager.isGrabbed(zone: widgetZone)
            zlayer.backgroundColor   = (shouldHighlight ? stateManager.lineColor : stateManager.unselectedColor).cgColor
            isUserInteractionEnabled = false

            snp.makeConstraints { (make) in
                let width: CGFloat = asToggle ? stateManager.dotLength : stateManager.dotLength * 0.65

                make.size.equalTo(CGSize(width: width, height: stateManager.dotLength))
            }

            addBorder(thickness: stateManager.dotThicknes, radius: radius, color: stateManager.lineColor.cgColor)
        }

        updateConstraints()
    }


    func hitAction(_ sender: AnyObject) {
        if isOuterDot {
            let widget: ZoneWidget = superview as! ZoneWidget

            if let zone = widget.widgetZone {
                if toggle == true {
                    zonesManager.toggleChildrenVisibility(zone)
                } else {
                    zonesManager.currentlyGrabbedZones = [zone]
                }
            }
        }
    }


    #if os(OSX)

    override func mouseDown(with event: ZEvent) {
        super.mouseDown(with:event)

        hitAction(self)
    }

    #elseif os(iOS)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        hitAction(self)
    }
    
    #endif
}
