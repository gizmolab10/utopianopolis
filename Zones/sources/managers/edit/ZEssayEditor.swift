//
//  ZEssayEditor.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 12/22/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

let gEssayEditor = ZEssayEditor()

class ZEssayEditor: NSObject {
	
	@discardableResult func handleKey(_ iKey: String?, flags: ZEventFlags, isWindow: Bool) -> Bool {   // false means key not handled
		if  var     key = iKey {
			let COMMAND = flags.isCommand
			let  OPTION = flags.isOption
			let SPECIAL = COMMAND && OPTION
			
			if  key    != key.lowercased() {
				key     = key.lowercased()
			}
			
			switch key {
				case kEscape,
					 "w": essay()
				case "/": if SPECIAL { gGraphEditor.showHideKeyboardShortcuts() }
				default:  break
			}
		}
		
		return false
	}

	func handleMenuItem(_ iItem: ZMenuItem?) {
		if  gWorkMode == .essayMode,
			let   item = iItem {
			let  flags = item.keyEquivalentModifierMask
			let    key = item.keyEquivalent
			
			handleKey(key, flags: flags, isWindow: true)
		}
	}

	func essay() {
		gWorkMode = (gWorkMode == .essayMode) ? .graphMode : .essayMode
		
		gControllers.signalFor(nil, regarding: .eEssay)
	}

}
