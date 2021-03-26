//
//  ZHelpEditor.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/25/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

let gHelpEditor = ZHelpEditor()

class ZHelpEditor: ZBaseEditor {

	override var canHandleKey: Bool { return true }

	@discardableResult override func handleKey(_ iKey: String?, flags: ZEventFlags, isWindow: Bool) -> Bool {   // false means key not handled
		if !super.handleKey(iKey, flags: flags, isWindow: isWindow) {
			if  let    key = iKey {
				switch key {
					case "/": gHelpController?.show(flags: flags); return true
					default:  break
				}
			}

			return false
		}

		return true
	}

}
