//
//  ZGestureAndKeyRecognizer.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/11/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

//
//protocol ZGestureModifiers {
//    
//    var modifiers: ZEventFlags?
//    override var isShiftDown:   Bool
//    override var isOptionDown:  Bool
//    override var isCommandDown: Bool
//
//    
//}
//
//
//extension ZGestureRecognizer {
//    
//    var modifiers: ZEventFlags? = ZEventFlags()
//    override var isShiftDown:   Bool { return modifiers?.contains(.shift)     ?? false }
//    override var isOptionDown:  Bool { return modifiers?.contains(.alternate) ?? false }
//    override var isCommandDown: Bool { return modifiers?.contains(.command)   ?? false }
//
//}


class ZKeyEdgeSwipeGestureRecognizer : ZEdgeSwipeGestureRecognizer {}


class ZKeyPanGestureRecognizer : ZPanGestureRecognizer {


    var modifiers: ZEventFlags? = ZEventFlags()
    override var isShiftDown:   Bool { return modifiers?.contains(.shift)     ?? false }
    override var isOptionDown:  Bool { return modifiers?.contains(.alternate) ?? false }
    override var isCommandDown: Bool { return modifiers?.contains(.command)   ?? false }


    open override func reset() {
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


    open override func reset() {
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


    open override func reset() {
        modifiers = ZEventFlags()
    }


    open func mouseDown (with event: ZEvent) {
        modifiers = event.modifierFlags
    }
    
}
