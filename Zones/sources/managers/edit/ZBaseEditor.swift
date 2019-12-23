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
	var workMode: ZWorkMode { return .startupMode }
	var previousEvent: ZEvent?

	@discardableResult func handleKey(_ iKey: String?, flags: ZEventFlags, isWindow: Bool) -> Bool { return false }   // false means key not handled
	
	@IBAction func genericMenuHandler(_ iItem: NSMenuItem?) {
		gDesktopAppDelegate?.genericMenuHandler(iItem)
	}

	func handleMenuItem(_ iItem: ZMenuItem?) {
		if  gWorkMode == workMode,
			let   item = iItem {
			let  flags = item.keyEquivalentModifierMask
			let    key = item.keyEquivalent
			
			handleKey(key, flags: flags, isWindow: true)
		}
	}

	@discardableResult func handleEvent(_ iEvent: ZEvent, isWindow: Bool) -> ZEvent? {
		if  gWorkMode    == workMode,
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

	func essay() {
		gWorkMode = (gWorkMode == .essayMode) ? .graphMode : .essayMode
		
		gControllers.signalFor(nil, regarding: .eEssay)
	}

}
