//
//  ZTooltipButton.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/13/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

class ZTooltipButton: ZButton {

	var originalBackgroundColor: ZColor?

	func updateTracking() {
		for area in trackingAreas {
			removeTrackingArea(area)
		}

		let options : NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .cursorUpdate] as NSTrackingArea.Options
		let tracker = NSTrackingArea(rect:frame, options: options, owner:self, userInfo: nil)

		addTrackingArea(tracker)
	}

	override func mouseEntered(with event: NSEvent) {
		if  let                   c = cell as? NSButtonCell {
			originalBackgroundColor = c.backgroundColor
			c.backgroundColor       = kLightestGrayColor
		}

		super.mouseEntered(with: event)
	}

	override func mouseExited(with event: NSEvent) {
		if  let             c = cell as? NSButtonCell {
			c.backgroundColor = originalBackgroundColor
		}

		super.mouseExited(with: event)
	}
}
