//
//  ZContextualMenu.swift
//  Sincerely
//
//  Created by Jonathan Sand on 4/20/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

class ZContextualMenu: NSMenu {

	@IBAction func genericMenuHandler(_ iItem: NSMenuItem?) {
		if  let item = iItem {
			let  key = item.keyEquivalent

			handleKey(key)
		}
	}

	func handleKey(_ key: String) {
		switch key {
			case "c": gMapController?.recenter()
			case "k": gColorfulMode = !gColorfulMode; gSignal([.sDatum])
			case "y": gToggleShowTooltips()
			case kEquals,
				 "-": gMapEditor.updateSize(up: key == kEquals)
			default:  break
		}
	}

}
