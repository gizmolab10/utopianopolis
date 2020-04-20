//
//  ZContextualMenu.swift
//  iFocus
//
//  Created by Jonathan Sand on 4/20/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZContextualMenu: NSMenu {

	var textWidget: ZoneTextWidget?

	@IBAction func genericMenuHandler(_ iItem: NSMenuItem?) {
		if  let item = iItem,
			let w = textWidget,
			w.validateMenuItem(item) {
			let key = item.keyEquivalent

			handleKey(key)
		}
	}

	func handleKey(_ key: String) {
		let zone = textWidget?.widgetZone

		switch key {
			case "b": zone?.addBookmark()
//			case "d": zone?.duplicate()
			case "n": zone?.showNote()
			case "/": zone?.focus()
			default:  break
		}
	}

}
