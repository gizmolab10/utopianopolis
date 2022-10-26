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

class ZBaseEditor : NSObject {
	var previousEvent: ZEvent?
	var canHandleKey: Bool { return false }   // filter whether menu and event handlers will call handle key

	func isValid(_ key: String, _ flags: ZEventFlags, inWindow: Bool = true) -> Bool { return true }
	@IBAction func genericMenuHandler(_ iItem: ZMenuItem?) { gAppDelegate?.genericMenuHandler(iItem) }

	@discardableResult func handleKey(_ iKey: String?, flags: ZEventFlags, isWindow: Bool) -> Bool {
		if  var key  = iKey {
			if  key != key.lowercased() {
				key  = key.lowercased()
			}

			gTemporarilySetKey(key)

			if  flags.exactlySpecial {
				switch key {
					case "a": gApplication?.showHideAbout();              return true
					case "k": toggleColorfulMode();                       return true
					case "o": gFiles.showInFinder();                      return true
					case "r": sendEmailBugReport();                       return true
					case "w": reopenMainWindow();                         return true
					case "x": clearRecents();                             return true
					case "/": gHelpController?.show(       flags: flags); return true
					default:  break
				}
			} else if flags.isCommand {
				switch key {
					case "e": gToggleShowExplanations();                  return true
					case "h": gApplication?.hide(nil);                    return true
					case "q": gApplication?.terminate(self);              return true
					case "w": gApplication?.keyWindow?.orderOut(self);    return true
					case "y": gToggleShowToolTips();                      return true
					case "'": gToggleLayoutMode();                        return true
					default:  break
				}
			}
		}

		return false
	}

	func handleMenuItem(_ iItem: ZMenuItem?) {
		if  canHandleKey,
			let   item = iItem {
			let  flags = item.keyEquivalentModifierMask
			let    key = item.keyEquivalent
			
			handleKey(key, flags: flags, isWindow: true)
		}
	}

	func invalidMenuItemAlert(_ menuItem: ZMenuItem) -> ZAlert? { return nil }

	open func validateMenuItem(_ menuItem: ZMenuItem) -> Bool {
		return isValid(menuItem.keyEquivalent, menuItem.keyEquivalentModifierMask)
	}

	@discardableResult func handleEvent(_ event: ZEvent, isWindow: Bool, forced: Bool = false) -> ZEvent? {
		if  (canHandleKey || forced),
			!gIgnoreEvents,
			!matchesPrevious(event) {
			previousEvent  = event
			
			if         gHelpWindow?.isKeyWindow ?? false {
				return gHelpController?.handleEvent(event) // better to detect here than in ZEvents.localMonitor
			} else if  gIsSearching {
				return gSearchBarController?.handleEvent(event)
			} else if  handleKey(event.key, flags: event.modifierFlags, isWindow: isWindow) {
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

		gSignal([.spRelayout, .spPreferences, .sDetails])
	}

	func reopenMainWindow() {
		gMainWindow?.makeKeyAndOrderFront(self)
		assignAsFirstResponder(gMapView)
		gSignal([.spRelayout])
	}

}
