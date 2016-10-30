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


class ZoneDot: ZButton {


    var toggle: Bool!


    func setUp(_ widgetZone: Zone, asToggle: Bool) {
        title               = ""
        onHit               = #selector(hitAction(_:))
        toggle              = asToggle
        isCircular          = asToggle
//        let shouldHighlight = asToggle ? widgetZone.showChildren : zonesManager.isGrabbed(zone: widgetZone)

//        setButtonType(.onOff) // fix for ios

        snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 9, height: 9))
        }

        updateConstraints()
//        highlight(shouldHighlight)
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
}
