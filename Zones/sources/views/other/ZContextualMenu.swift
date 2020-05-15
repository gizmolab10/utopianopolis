//
//  ZContextualMenu.swift
//  Sincerely
//
//  Created by Jonathan Sand on 4/20/20.
//  Copyright © 2020 Zones. All rights reserved.
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
			case "c":    break
			case "k":    break
			case "p":    break
			case "=":    break
			case "_":    break
			default:     break
		}
	}

}
