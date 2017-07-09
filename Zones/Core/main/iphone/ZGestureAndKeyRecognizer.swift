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


    var modifiers: ZEventFlags? = nil
    override var isShiftDown: Bool { return modifiers?.contains(.shift) ?? false }


    open func reset() {
        modifiers = nil
    }


    open func mouseDown (with event: ZEvent) {
        modifiers = event.modifierFlags
    }

}


class ZKeyClickGestureRecognizer: ZClickGestureRecognizer {


    var modifiers: ZEventFlags? = nil
    override var isShiftDown: Bool { return modifiers?.contains(.shift) ?? false }


    open func reset() {
        modifiers = nil
    }


    open func mouseDown (with event: ZEvent) {
        modifiers = event.modifierFlags
    }
    
}


class ZKeySwipeGestureRecognizer : ZSwipeGestureRecognizer {


    var modifiers: ZEventFlags? = nil
    override var isShiftDown: Bool { return modifiers?.contains(.shift) ?? false }


    open func reset() {
        modifiers = nil
    }


    open func mouseDown (with event: ZEvent) {
        modifiers = event.modifierFlags
    }
    
}
