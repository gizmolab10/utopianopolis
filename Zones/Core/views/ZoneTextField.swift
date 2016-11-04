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

    
    #if os(OSX)

    var textAlignment : NSTextAlignment { get { return alignment } set { alignment = newValue } }


    override func mouseDown(with event: ZEvent) {
        super.mouseDown(with:event)

        zoneWidgetDelegate!.selectForEditing()
    }

    #elseif os(iOS)

    var isBordered : Bool { get { return borderStyle != .none } set { borderStyle = (newValue ? .line : .none) } }


    func mouseDown(with event: ZEvent) {
        zoneWidgetDelegate!.selectForEditing()
    }

    #endif
}
