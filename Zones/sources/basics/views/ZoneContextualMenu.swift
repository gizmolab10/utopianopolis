//
//  ZoneContextualMenu.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/20/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

class ZoneContextualMenu: ZContextualMenu {

	var textWidget: ZoneTextWidget?
	var zone: Zone? { return textWidget?.widgetZone }

	@IBAction override func genericMenuHandler(_ iItem: ZMenuItem?) {
		if  let item = iItem,
			let w = textWidget,
			w.validateMenuItem(item) {
			let key = item.keyEquivalent

			handleKey(key)
		}
	}

	override func handleKey(_ key: String) {
		if  ["l", "u"].contains(key) {
			textWidget?.alterCase(up: key == "u")
		} else {
			zone?.handleContextualMenuKey(key)
		}
	}

}
