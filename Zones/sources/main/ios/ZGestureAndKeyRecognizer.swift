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


    var modifiers: ZEventFlags? = ZEventFlags()
    override var isShiftDown:   Bool { return modifiers?.contains(.shift)     ?? false }
    override var isOptionDown:  Bool { return modifiers?.contains(.alternate) ?? false }
    override var isCommandDown: Bool { return modifiers?.contains(.command)   ?? false }


    open func reset() {
        modifiers = ZEventFlags()
    }


    open func mouseDown (with event: ZEvent) {
        modifiers = event.modifierFlags
    }

}


class ZKeyClickGestureRecognizer: ZClickGestureRecognizer {


    var modifiers: ZEventFlags? = ZEventFlags()
    override var isShiftDown:   Bool { return modifiers?.contains(.shift)     ?? false }
    override var isOptionDown:  Bool { return modifiers?.contains(.alternate) ?? false }
    override var isCommandDown: Bool { return modifiers?.contains(.command)   ?? false }


    open func reset() {
        modifiers = ZEventFlags()
    }


    open func mouseDown (with event: ZEvent) {
        modifiers = event.modifierFlags
    }
    
}


class ZKeySwipeGestureRecognizer : ZSwipeGestureRecognizer {


    var modifiers: ZEventFlags? = ZEventFlags()
    override var isShiftDown:   Bool { return modifiers?.contains(.shift)     ?? false }
    override var isOptionDown:  Bool { return modifiers?.contains(.alternate) ?? false }
    override var isCommandDown: Bool { return modifiers?.contains(.command)   ?? false }


    open func reset() {
        modifiers = ZEventFlags()
    }


    open func mouseDown (with event: ZEvent) {
        modifiers = event.modifierFlags
    }
    
}
