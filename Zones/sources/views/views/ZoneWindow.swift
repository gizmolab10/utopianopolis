//
//  ZoneWindow.swift
//  Seriously
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

    static var window : ZoneWindow?
    var      observer : NSKeyValueObservation?
	var  lastLocation = NSPoint.zero

	@discardableResult func handleKey(_ iKey: String?, flags: ZEventFlags) -> Bool {   // false means key not handled
		if  let            key = iKey {
			gCurrentKeyPressed = key // enable become first responder

			// //////////////////////////////////////// //
			// dispatch key handling to various editors //
			// //////////////////////////////////////// //

			switch gWorkMode {
				case .noteMode:     return gEssayEditor             .handleKey(key, flags: flags, isWindow: true)
				case .graphMode:    return gGraphEditor             .handleKey(key, flags: flags, isWindow: true)
				case .searchMode:   return gSearchResultsController?.handleKey(key, flags: flags) ?? false
				case .editIdeaMode: return gTextEditor              .handleKey(key, flags: flags)
				default:            break
			}
		}

		return false
	}

	var keyPressed: Bool {
		let    e  = nextEvent(matching: .keyDown, until: Date(), inMode: .default, dequeue: false)

		return e != nil
	}

	var mouseMoved: Bool {
		let last = lastLocation
		let  now = mouseLocationOutsideOfEventStream

		if  contentView?.frame.contains(now) ?? false {
			lastLocation = now
		}

		return last != lastLocation
	}

	func windowDidResize(_ notification: Notification) {
		gWindowRect = frame

		gSignal([.sResize])
	}

    #if os(OSX)

	func windowWillClose(_ notification: Notification) {
		gApplication.terminate(self)
	}

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
