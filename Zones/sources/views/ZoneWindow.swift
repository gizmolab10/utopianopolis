//
//  ZoneWindow.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


var gWindow: ZoneWindow? { return ZoneWindow.window }


class ZoneWindow: ZWindow, ZWindowDelegate {


    static var window: ZoneWindow?
    var observer: NSKeyValueObservation?


    override func awakeFromNib() {
        super.awakeFromNib()

        let        button = standardWindowButton(NSWindow.ButtonType.closeButton) // hide close button ... zoomButton miniaturizeButton
        button!.isHidden  = true
        delegate          = self
        ZoneWindow.window = self
        contentMinSize    = kDefaultWindowRect.size // smallest size user to which can shrink window
        let          rect = gWindowRect
        
        setFrame(rect, display: true)

        observer = observe(\.effectiveAppearance) { _, _  in
            gControllers.signalFor(nil, regarding: .eAppearance)
        }
    }


    func windowDidResize(_ notification: Notification) {
        gWindowRect = frame
        
        gControllers.signalFor(nil, regarding: .eDebug)
    }


    #if os(OSX)

    override open var acceptsFirstResponder: Bool { return true }

    // cannot declare this in extensions because compiler barfs about objective-c method conflict (and then compiler throws a seg fault)

    override func keyDown(with event: ZEvent) {
        if  !isDuplicate(event: event),
            gGraphEditor.handleEvent(event, isWindow: true) != nil {
            super.keyDown(with: event)
        }
    }
    
    func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any? {
        return gTextEditor
    }

    #endif
}
