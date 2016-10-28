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


    func setUp() {
        isHidden       = widget.widgetZone.children.count == 0

        if !isHidden {
            title      = ""
            target     = self
            action     = #selector(hitAction(_:))
            bezelStyle = .circular

            setButtonType(.momentaryLight)

            snp.makeConstraints { (make) in
                make.size.equalTo(CGSize(width: 8, height: 8))
            }
            
            updateConstraints()
        }
    }


    var widget: ZoneWidget {
        get { return superview as! ZoneWidget }
    }



    @objc func hitAction(_ sender: AnyObject) {
        let zone = widget.widgetZone

        modelManager.toggleExpansion(zone)
    }
}
