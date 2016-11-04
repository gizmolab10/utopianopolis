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
        toggle                     = asToggle

        if isOuterDot {
            zlayer.backgroundColor = ZColor.clear.cgColor
            innerDot               = ZoneDot()
            innerDot?.isOuterDot   = false
            // let radius:    CGFloat = userTouchLength / 2.0

            self.addSubview(innerDot!)
            innerDot?.setupForZone(widgetZone, asToggle: asToggle)
            // addBorder(thickness: stateManager.lineThicknes, radius: radius, color: ZColor.red.cgColor)
            snp.makeConstraints { (make) in
                make.size.equalTo(CGSize(width: userTouchLength, height: userTouchLength))
                make.center.equalTo(innerDot!)
            }
            setupUserInteraction(isOuterDot)
        } else {
            let radius:    CGFloat = stateManager.dotLength * 0.5 * (asToggle ? 1.0 : 0.65)
            shouldHighlight        = asToggle ? !widgetZone.showChildren : zonesManager.isGrabbed(zone: widgetZone)
            zlayer.backgroundColor = (shouldHighlight ? stateManager.lineColor : stateManager.unselectedColor).cgColor

            addBorder(thickness: stateManager.lineThicknes, radius: radius, color: stateManager.lineColor.cgColor)
            snp.makeConstraints { (make) in
                let width: CGFloat = asToggle ? stateManager.dotLength : stateManager.dotLength * 0.65

                make.size.equalTo(CGSize(width: width, height: stateManager.dotLength))
            }
        }

        updateConstraints()
    }


    func hitAction(_ sender: AnyObject) {
        let widget: ZoneWidget = superview as! ZoneWidget

        if let zone = widget.widgetZone {
            if toggle == true {
                zonesManager.toggleChildrenVisibility(zone)
            } else {
                zonesManager.currentlyGrabbedZones = [zone]
            }
        }
    }


    #if os(OSX)

    override func mouseDown(with event: ZEvent) {
        super.mouseDown(with:event)

        if isOuterDot {
            hitAction(self)
        }
    }
    

    func setupUserInteraction(_ enable: Bool) {}

    #elseif os(iOS)

    func handleTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            hitAction(self)
        }
    }


    func setupUserInteraction(_ enable: Bool) {
        isUserInteractionEnabled = enable

        if enable {
            let gesture = UITapGestureRecognizer(target: self, action: #selector(ZoneDot.handleTap))

            self.addGestureRecognizer(gesture)
        }
    }

    #endif
}
