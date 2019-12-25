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

class ZEssayEditor: ZBaseEditor {
	override var workMode: ZWorkMode { return .essayMode }
	var zone: Zone? { return gSelecting.firstGrab }

	override func isValid(_ key: String, _ flags: ZEventFlags, inWindow: Bool = true) -> Bool {
		if  gWorkMode != .essayMode || inWindow {
			return false
		}

		return true
	}

	@discardableResult override func handleKey(_ iKey: String?, flags: ZEventFlags, isWindow: Bool) -> Bool {   // false means key not handled
		if  var     key = iKey {
			let COMMAND = flags.isCommand
			let  OPTION = flags.isOption
			let SPECIAL = COMMAND && OPTION
			
			if  key    != key.lowercased() {
				key     = key.lowercased()
			}
			
			switch key {
				case kEscape: 		   swapGraphAndEssay()
				case "w": if COMMAND { swapGraphAndEssay() }
				case "/": if SPECIAL { showHideKeyboardShortcuts() }
				default:  			   break
			}
		}
		
		return false
	}
	
}
