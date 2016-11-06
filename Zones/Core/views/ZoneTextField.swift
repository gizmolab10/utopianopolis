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


protocol ZoneTextFieldDelegate {
    func selectForEditing()
}


class ZoneTextField: ZTextField {


    var zoneWidgetDelegate: ZoneTextFieldDelegate?


    func setup() {
        font            = widgetFont
        isBordered      = false
        textAlignment   = .center
        backgroundColor = ZColor.clear

        setupGestures(target: self, action: #selector(ZoneTextField.gestureEvent))
    }


    func gestureEvent(_ sender: ZGestureRecognizer?) {
        zoneWidgetDelegate?.selectForEditing()
    }
}
