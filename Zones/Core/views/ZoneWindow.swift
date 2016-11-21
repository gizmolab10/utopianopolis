//
//  ZoneWindow.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneWindow: NSWindow {


    override var acceptsFirstResponder: Bool { get { return true } }


    override func performKeyEquivalent(with event: ZEvent) -> Bool {
        if let string = event.charactersIgnoringModifiers {
            let first = string[string.startIndex].description

            controllersManager.updateToClosures(first as NSObject?, regarding: .key)

            if first == "\r" {
                return true
            }
        }

        return false
    }

}
