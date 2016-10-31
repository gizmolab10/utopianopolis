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
    var shouldHighlight: Bool = false


    func setUp(_ widgetZone: Zone, asToggle: Bool) {
        toggle                   = asToggle
        let     radius : CGFloat = stateManager.dotLength * 0.5 * (asToggle ? 1.0 : 0.65)
        shouldHighlight          = asToggle ? !widgetZone.showChildren : zonesManager.isGrabbed(zone: widgetZone)
        zlayer.backgroundColor   = (shouldHighlight ? stateManager.lineColor : stateManager.unselectedColor).cgColor
        isUserInteractionEnabled = true

        snp.makeConstraints { (make) in
            let width: CGFloat = asToggle ? stateManager.dotLength : stateManager.dotLength * 0.65

            make.size.equalTo(CGSize(width: width, height: stateManager.dotLength))
        }

        updateConstraints()
        addBorder(thickness: stateManager.dotThicknes, radius: radius, color: stateManager.lineColor.cgColor)
    }


    var widget: ZoneWidget {
        get { return superview as! ZoneWidget }
    }


    func hitAction(_ sender: AnyObject) {
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

        hitAction(self)
    }

    #elseif os(iOS)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        hitAction(self)
    }
    
    #endif
}
