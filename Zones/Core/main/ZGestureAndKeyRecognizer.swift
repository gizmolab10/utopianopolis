//
//  ZGestureAndKeyRecognizer.swift
//  Zones
//
//  Created by Jonathan Sand on 6/11/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZKeyPanGestureRecognizer : ZPanGestureRecognizer {


    var modifiers: NSEventModifierFlags? = nil


    override open func reset() {
        modifiers = nil
    }


    override open func mouseDown (with event: NSEvent) {
        super.mouseDown (with: event)
        modifiers = event.modifierFlags
    }

}


class ZKeyClickGestureRecognizer: ZClickGestureRecognizer {


    var modifiers: NSEventModifierFlags? = nil


    override open func reset() {
        modifiers = nil
    }


    override open func mouseDown (with event: NSEvent) {
        super.mouseDown (with: event)
        modifiers = event.modifierFlags
    }
    
}
