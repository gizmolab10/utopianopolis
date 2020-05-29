//
//  ZBaseEditor.swift
//  Seriously
//
//  Created by Jonathan Sand on 12/23/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class ZBaseEditor: NSObject {
	var previousEvent: ZEvent?
	var canHandleKey: Bool { return false }   // filter whether menu and event handlers will call handle key

	func isValid(_ key: String, _ flags: ZEventFlags, inWindow: Bool = true) -> Bool { return false }
	@IBAction func genericMenuHandler(_ iItem: NSMenuItem?) { gDesktopAppDelegate?.genericMenuHandler(iItem) }

	@discardableResult func handleKey(_ iKey: String?, flags: ZEventFlags, isWindow: Bool) -> Bool {
		var     handled = false
		if  var     key = iKey {
			let COMMAND = flags.isCommand
			let  OPTION = flags.isOption
			let SPECIAL =  COMMAND && OPTION
			let ONEFLAG = (COMMAND || OPTION) && !SPECIAL

			if  key    != key.lowercased() {
				key     = key.lowercased()
			}

			gTemporarilySetKey(key)

			switch key {
				case "a": if SPECIAL { gApplication.showHideAbout(); handled = true }
				case "h": if COMMAND { gApplication.hide(nil);       handled = true }
				case "k": if SPECIAL { toggleColorfulMode();         handled = true }
				case "o": if SPECIAL { gFiles.showInFinder();        handled = true }
				case "p": if SPECIAL { cycleSkillLevel();            handled = true }
				case "q": if COMMAND { gApplication.terminate(self); handled = true }
				case "r": if SPECIAL { sendEmailBugReport();         handled = true }
				case "t": if ONEFLAG { fetchTraits();                handled = true }
				case "x": if SPECIAL { wipeRing();                   handled = true }
				case "/": if SPECIAL { gControllers.showShortcuts(); handled = true }
				default:  break
			}
		}

		return handled
	}

	func handleMenuItem(_ iItem: ZMenuItem?) {
		if  canHandleKey,
			let   item = iItem {
			let  flags = item.keyEquivalentModifierMask
			let    key = item.keyEquivalent
			
			handleKey(key, flags: flags, isWindow: true)
		}
	}

	@discardableResult func handleEvent(_ iEvent: ZEvent, isWindow: Bool) -> ZEvent? {
		if  canHandleKey,
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

	func smartGo(forward: Bool, notForceRecents: Bool = false, amongNotes: Bool = false) {
		if  gIsRecentlyMode && !notForceRecents {
			gRecents.go(forward: forward)
		} else {
			gFavorites.go(forward) { gRedrawGraph() }
		}
	}

	func wipeRing() {
		if  gIsNoteMode {
			gControllers.swapGraphAndEssay()
		}

		gCurrentEssay = nil
	}

	func fetchTraits() {
		gBatches.allTraits { flag in
			gRedrawGraph()
		}
	}

	func toggleColorfulMode() {
		gColorfulMode = !gColorfulMode

		gRedrawGraph()
	}

}
