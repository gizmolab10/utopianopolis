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


    @discardableResult override func resignFirstResponder() -> Bool {
        zonesManager.currentlyEditingZone = nil

        return super.resignFirstResponder()
    }


    @discardableResult override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()

        if result {
            zonesManager.currentlyEditingZone = widgetZone
        }

        return result
    }


    // fix a bug where root zone is editing on launch

    #if os(OSX)

    override var acceptsFirstResponder: Bool { get { return stateManager.isReady } }

    #elseif os(iOS)

    override var canBecomeFirstResponder: Bool { get { return stateManager.isReady } }

    #endif
}
