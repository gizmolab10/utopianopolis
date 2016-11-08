//
//  ZoneTextField.swift
//  Zones
//
//  Created by Jonathan Sand on 10/27/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneTextField: ZTextField {


    var widgetZone: Zone!


    func setup() {
        font                   = widgetFont
        isBordered             = false
        textAlignment          = .center
        backgroundColor        = ZColor.clear
        zlayer.backgroundColor = ZColor.clear.cgColor
    }
}
