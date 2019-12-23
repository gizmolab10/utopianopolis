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
	
	@discardableResult func handleKey(_ iKey: String?, flags: ZEventFlags, isWindow: Bool) -> Bool { return false }   // false means key not handled

	func handleMenuItem(_ iItem: ZMenuItem?) {
		if  gWorkMode == workMode,
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
