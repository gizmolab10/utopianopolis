//
//  ZBaseEditor.swift
//  Zones
//
//  Created by Jonathan Sand on 12/23/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class ZBaseEditor: NSObject {
	var previousEvent: ZEvent?

	func isValid(_ key: String, _ flags: ZEventFlags, inWindow: Bool = true) -> Bool { return false }
	func canHandleKey() -> Bool { return false }   // filter whether menu and event handlers will call handle key

	@IBAction func genericMenuHandler(_ iItem: NSMenuItem?) {
		gDesktopAppDelegate?.genericMenuHandler(iItem)
	}

	@discardableResult func handleKey(_ iKey: String?, flags: ZEventFlags, isWindow: Bool) -> Bool {
		if  var     key = iKey {
			let COMMAND = flags.isCommand
			let  OPTION = flags.isOption
			let SPECIAL = COMMAND && OPTION

			if  key    != key.lowercased() {
				key     = key.lowercased()
			}

			gCurrentKeyPressed = key

			switch key {
				case "a": if SPECIAL { gApplication.showHideAbout(); gCurrentKeyPressed = nil; return true }
				case "h": if COMMAND { gApplication.hide(nil);       gCurrentKeyPressed = nil; return true }
				case "o": if SPECIAL { gFiles.showInFinder();        gCurrentKeyPressed = nil; return true }
				case "q": if COMMAND { gApplication.terminate(self); gCurrentKeyPressed = nil; return true }
				case "t": if COMMAND { fetchTraits();                gCurrentKeyPressed = nil; return true }
				case "x": if SPECIAL { wipeRing();                   gCurrentKeyPressed = nil; return true }
				case "/": if SPECIAL { gControllers.showShortcuts(); gCurrentKeyPressed = nil; return true }
				default:  break
			}
		};                                                           gCurrentKeyPressed = nil; return false
	}

	func handleMenuItem(_ iItem: ZMenuItem?) {
		if  canHandleKey(),
			let   item = iItem {
			let  flags = item.keyEquivalentModifierMask
			let    key = item.keyEquivalent
			
			handleKey(key, flags: flags, isWindow: true)
		}
	}

	@discardableResult func handleEvent(_ iEvent: ZEvent, isWindow: Bool) -> ZEvent? {
		if  canHandleKey(),
			!matchesPrevious(iEvent) {
			let     flags = iEvent.modifierFlags
			previousEvent = iEvent
			
			if  handleKey(iEvent.key, flags: flags, isWindow: isWindow) {
				return nil
			}
		}
		
		return iEvent
	}
	
	func matchesPrevious(_ iEvent: ZEvent) -> Bool {
		#if os(OSX)
		return iEvent == previousEvent
		#else
		return false // on iOS events don't pile up??????
		#endif
	}

	func wipeRing() {
		gEssayRing.clear()
		gFocusRing.clear()
		gFocusRing.push()

		if  gIsNoteMode {
			gControllers.swapGraphAndEssay()
		}

		gCurrentEssay = nil
	}

	func fetchTraits() {
		gBatches.allTraits { flag in
			self.signal([.eRelayout])
		}
	}

}
