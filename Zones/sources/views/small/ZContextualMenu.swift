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
	var zone: Zone? { return textWidget?.widgetZone }

	@IBAction func genericMenuHandler(_ iItem: NSMenuItem?) {
		if  let item = iItem,
			let w = textWidget,
			w.validateMenuItem(item) {
			let key = item.keyEquivalent

			handleKey(key)
		}
	}

	func handleKey(_ key: String) {
		if  let arrow = key.arrow {
			switch arrow {
				case .left:  zone?.applyGenerationally(false)
				case .right: zone?.applyGenerationally(true)
				default:     break
			}
		} else {
			switch key {
				case "b": zone?.addBookmark()
//				case "d": zone?.duplicate()
				case "e": zone?.editTrait(for: .tEmail)
				case "h": zone?.editTrait(for: .tHyperlink)
				case "l": textWidget?.alterCase(up: false)
				case "n": zone?.showNote()
				case "u": textWidget?.alterCase(up: true)
				case "/": zone?.focus()
				default:  break
			}
		}
	}

}
