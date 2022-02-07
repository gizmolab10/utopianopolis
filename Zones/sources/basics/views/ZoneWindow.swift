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

var gMainWindow : ZoneWindow? { return ZoneWindow.mainWindow }
var gHelpWindow : ZWindow?    { return gHelpWindowController?.window }

class ZoneWindow: ZWindow, ZWindowDelegate {

    static var mainWindow : ZoneWindow?
    var          observer : NSKeyValueObservation?
	var      inspectorBar : ZView? { return titlebarAccessoryViewControllers.first(where: { $0.view.className == "__NSInspectorBarView" } )?.view }

	func redrawInspectorBar(_ enabled: Bool) {
		if  let      bar = inspectorBar {
			bar.isHidden = !enabled

			if  enabled {
				bar.setNeedsDisplay()
			}
		}
	}

	@discardableResult func handleKey(_ iKey: String?, flags: ZEventFlags) -> Bool {   // false means key not handled
		if  let            key = iKey {
			gTemporarilySetKey(key)  // enable become first responder

			// //////////////////////////////////////// //
			// dispatch key handling to various editors //
			// //////////////////////////////////////// //

			switch gWorkMode {
				case .wEssayMode:    return gEssayEditor             .handleKey(key, flags: flags, isWindow: true)
				case .wMapMode:      return gMapEditor               .handleKey(key, flags: flags, isWindow: true)
				case .wSearchMode:   return gSearchResultsController?.handleKey(key, flags: flags) ?? false
				case .wEditIdeaMode: return gTextEditor              .handleKey(key, flags: flags)
				default:             break
			}
		}

		return false
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
            gMapEditor.handleEvent(event, isWindow: true) != nil {
            super.keyDown(with: event)
        }
    }
    
    func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any? {
        return gTextEditor
    }

	func updateEssayEditorInspectorBar(show: Bool = false) {
		showsToolbarButton     =  show
		inspectorBar?.isHidden = !show
	}

    #endif
}
