//
//  ZContextualMenu.swift
//  Sincerely
//
//  Created by Jonathan Sand on 4/20/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

class ZContextualMenu: ZMenu {

	@IBAction func genericMenuHandler(_ iItem: ZMenuItem?) {
		if  let item = iItem {
			let  key = item.keyEquivalent

			handleKey(key)
		}
	}

	func handleKey(_ key: String) {
		switch key {
			case kEquals,
				 kHyphen: gUpdateBaseFontSize(up: key == kEquals)
			case "c":     gMapController?.recenter()
			case "e":     gToggleShowExplanations()
			case "k":     gColorfulMode = !gColorfulMode; gSignal([.sDatum])
			case "y":     gToggleShowToolTips()
			default:  break
		}
	}

}
