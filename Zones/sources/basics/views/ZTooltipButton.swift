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

	func updateTracking() { addTracking(for: frame) }

	override func mouseEntered(with event: ZEvent) {
		if  isEnabled,
			let                   c = cell as? NSButtonCell {
			originalBackgroundColor = c.backgroundColor
			c.backgroundColor       = kLightestGrayColor
		}

		super.mouseEntered(with: event)
	}

	override func mouseExited(with event: ZEvent) {
		if  let             c = cell as? NSButtonCell {
			c.backgroundColor = originalBackgroundColor
		}

		super.mouseExited(with: event)
	}

	override func mouseUp(with event: ZEvent) {
		if  let             c = cell as? NSButtonCell {
			c.backgroundColor = originalBackgroundColor
		}

		super.mouseUp(with: event)
	}
}
