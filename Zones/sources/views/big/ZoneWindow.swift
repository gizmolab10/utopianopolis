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
	var lastLocation = NSPoint.zero
	var kvoContext: UInt8 = 1


	var keyPressed: Bool {
		let    e  = nextEvent(matching: .keyDown, until: Date(), inMode: .default, dequeue: false)
		return e != nil
	}

	var mouseMoved: Bool {
		let    last  = lastLocation
		lastLocation = mouseLocationOutsideOfEventStream

		return last != lastLocation
	}

	func windowDidResize(_ notification: Notification) {
		gWindowRect = frame

		signalMultiple([.eDebug, .eResize])
	}

    #if os(OSX)

	func windowWillClose(_ notification: Notification) {
		gApplication.terminate(self)
	}

    override open var acceptsFirstResponder: Bool { return true }

	func reattachWidgetForZone(_ zone: Zone?) {
		if  let widget = zone?.widget?.textWidget {
			gWindow?.contentView?.addSubview(widget)
		}
	}

    // cannot declare this in extensions because compiler barfs about objective-c method conflict (and then compiler throws a seg fault)

    override func keyDown(with event: ZEvent) {
        if  !isDuplicate(event: event),
            gGraphEditor.handleEvent(event, isWindow: true) != nil {
            super.keyDown(with: event)
        }
    }
    
    override func flagsChanged(with event: NSEvent) {
        let flags = event.modifierFlags

		if  flags.isOption && flags.isCommand && flags.isControl && gIsGraphMode {
            gControllers.showHideRing()
        }

        super.flagsChanged(with: event)
    }
    
    func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any? {
        return gTextEditor
    }

    #endif
}
