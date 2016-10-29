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


    func setUp(asToggle: Bool) {
        title      = ""
        onHit      = #selector(hitAction(_:))
        toggle     = asToggle
        isCircular = asToggle

        // setButtonType(.onOff)

        snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 8, height: 8))
        }

        updateConstraints()
    }


    var widget: ZoneWidget {
        get { return superview as! ZoneWidget }
    }


    @objc func hitAction(_ sender: AnyObject) {
        let zone = widget.widgetZone

        if toggle == true {
            modelManager.toggleExpansion(zone)
        }
    }
}
