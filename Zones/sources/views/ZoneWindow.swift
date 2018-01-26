//
//  ZoneWindow.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneWindow: ZWindow {


    static var window: ZoneWindow?


    override func awakeFromNib() {
        super.awakeFromNib()

        ZoneWindow.window = self

        standardWindowButton(NSWindow.ButtonType.zoomButton)!.isHidden = true
        standardWindowButton(NSWindow.ButtonType.closeButton)!.isHidden = true
        standardWindowButton(NSWindow.ButtonType.miniaturizeButton)!.isHidden = true
    }


    #if os(OSX)

    override open var acceptsFirstResponder: Bool { return true }

    // cannot declare this in extensions because compiler barfs about objective-c method conflict (and then compiler throws a seg fault)

    override func keyDown(with event: ZEvent) {
        if !gEditingManager.handleEvent(event, isWindow: true) {
            textInputReport("window")
            super.keyDown(with: event)
        }
    }

    #endif
}
