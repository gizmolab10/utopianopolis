//
//  ZEssayEditor.swift
//  Seriously
//
//  Created by Jonathan Sand on 12/22/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

let gEssayEditor = ZEssayEditor()

class ZEssayEditor: ZBaseEditor {

	override var canHandleKey: Bool { return gIsEssayMode }

	override func isValid(_ key: String, _ flags: ZEventFlags, inWindow: Bool = true) -> Bool {
		if !gIsEssayMode || !inWindow {
			return false
		}

		return true
	}

	@discardableResult override func handleKey(_ iKey: String?, flags: ZEventFlags, isWindow: Bool) -> Bool {   // false means key not handled
		return super.handleKey(iKey, flags: flags, isWindow: isWindow) || gEssayView?.handleKey(iKey, flags: flags) ?? false
	}

}

