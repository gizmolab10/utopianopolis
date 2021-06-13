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

	func isValid(_ key: String, _ flags: ZEventFlags, inWindow: Bool = true) -> Bool { return true }
	@IBAction func genericMenuHandler(_ iItem: ZMenuItem?) { gAppDelegate?.genericMenuHandler(iItem) }

	@discardableResult func handleKey(_ iKey: String?, flags: ZEventFlags, isWindow: Bool) -> Bool {
		var handled  = false
		if  var key  = iKey {
			if  key != key.lowercased() {
				key  = key.lowercased()
			}

			gTemporarilySetKey(key)

			if  flags.exactlySpecial {
				switch key {
					case "/": gHelpController?.show(       flags: flags); handled = true
					case "a": gApplication.showHideAbout();               handled = true
					case "k": toggleColorfulMode();                       handled = true
					case "o": gFiles.showInFinder();                      handled = true
					case "r": sendEmailBugReport();                       handled = true
					case "x": clearRecents();                             handled = true
					default:  break
				}
			} else if flags.isCommand {
				switch key {
					case "w": gHelpController?.show(false, flags: flags); handled = true
					case "h": gApplication.hide(nil);                     handled = true
					case "q": gApplication.terminate(self);               handled = true
					case "y": gToggleShowTooltips();                      handled = true
					default:  break
				}
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

	open func validateMenuItem(_ menuItem: ZMenuItem) -> Bool {
		return isValid(menuItem.keyEquivalent, menuItem.keyEquivalentModifierMask)
	}

	@discardableResult func handleEvent(_ event: ZEvent, isWindow: Bool) -> ZEvent? {
		if  canHandleKey,
			!matchesPrevious(event) {
			previousEvent  = event
			
			if  gHelpWindow?.isKeyWindow ?? false {
				return gHelpController?.handleEvent(event) // better to detect here than in ZEvents.localMonitor
			}

			if  handleKey(event.key, flags: event.modifierFlags, isWindow: isWindow) {
				return nil
			}
		}
		
		return event
	}

	func matchesPrevious(_ iEvent: ZEvent) -> Bool {
		#if os(OSX)
		return iEvent == previousEvent
		#else
		return false // on iOS events don't pile up??????
		#endif
	}

	func clearRecents() {
		if  gIsEssayMode {
			gControllers.swapMapAndEssay()
		}

		gCurrentEssay = nil
	}

	func toggleColorfulMode() {
		gColorfulMode = !gColorfulMode

		gSignal([.sRelayout, .spPreferences])
	}

}
