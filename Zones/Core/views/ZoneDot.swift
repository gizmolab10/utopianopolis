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


    var toggle: Bool!
    var shouldHighlight: Bool = false


    func setUp(_ widgetZone: Zone, asToggle: Bool) {
        toggle                 = asToggle
        shouldHighlight        = asToggle ? !widgetZone.showChildren : zonesManager.isGrabbed(zone: widgetZone)
        zlayer.backgroundColor = (shouldHighlight ? stateManager.lineColor : ZColor.white).cgColor

        snp.makeConstraints { (make) in
            let  width = asToggle ? 12 : 8
            let height = asToggle ? 12 : 16

            make.size.equalTo(CGSize(width: width, height: height))
        }

        updateConstraints()
        addBorder(thickness: 1.0, fractionalRadius: 0.3, color: stateManager.lineColor.cgColor)
    }


    var widget: ZoneWidget {
        get { return superview as! ZoneWidget }
    }


    @objc func hitAction(_ sender: AnyObject) {
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

    func mouseDown(with event: ZEvent) {
        hitAction(self)
    }
    
    #endif
}
