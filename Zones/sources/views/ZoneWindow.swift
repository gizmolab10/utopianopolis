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


class ZoneWindow: ZWindow, ZWindowDelegate {


    static var window: ZoneWindow?
    var observer: NSKeyValueObservation?


    override func awakeFromNib() {
        super.awakeFromNib()

        standardWindowButton(NSWindow.ButtonType.closeButton)!.isHidden = true // zoomButton miniaturizeButton
        delegate          = self
        ZoneWindow.window = self
        contentMinSize    = CGSize(width: 300, height: 300) // gWindowSize

        observer = observe(\.effectiveAppearance) { _, _  in
            gControllersManager.signalFor(nil, regarding: .appearance)
        }
    }


    func windowDidResize(_ notification: Notification) {
        if  let    size = contentView?.bounds.size {
            gWindowSize = size

            gControllersManager.signalFor(nil, regarding: .debug)
        }
    }


    #if os(OSX)

    override open var acceptsFirstResponder: Bool { return true }

    // cannot declare this in extensions because compiler barfs about objective-c method conflict (and then compiler throws a seg fault)

    override func keyDown(with event: ZEvent) {
        if  gCurrentEvent != event {
            gCurrentEvent  = event

            if  !gEditingManager.handleEvent(event, isWindow: true) {
                super.keyDown(with: event)
            }
        }
    }
    
    func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any? {
        return gTextManager
    }

    #endif
}
