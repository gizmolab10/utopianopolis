//
//  ZApplication.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/11/22.
//  Copyright © 2022 Zones. All rights reserved.
//

import Foundation
import AppKit

var gApplication: ZApplication?

class ZApplication : NSApplication {

	override func sendEvent(_ event: NSEvent) {
		super.sendEvent(event)

		let t  = event.type.rawValue
		if  t == 17 {
			gDebugCount += 1

			print("\(gDebugCount) cursor updated")
		}
	}

	func clearBadge() {
		dockTile.badgeLabel = kEmpty
	}

	func showHideAbout() {
		for     window in windows {
			if  window.isKeyWindow,
				window.isKind(of: NSPanel.self) { // check if about box is visible
				window.close()

				return
			}
		}

		orderFrontStandardAboutPanel(nil)
	}

}
