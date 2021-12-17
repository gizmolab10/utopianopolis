//
//  ZTooltipButton.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/13/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import CloudKit
import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class ZTooltipButton: ZButton, ZTooltips {

	var originalBackgroundColor: ZColor?

	override var isEnabled: Bool {
		get { return super.isEnabled }
		set { super.isEnabled = newValue; updateTooltips() }
	}

	override var size: CGSize {
		var result   = frame.size
//		if  let size = image?.size {
//			result   = size.offsetBy(20.0, 6.0)
//		} else
		if  let    f = font, image == nil {
			result   = title.sizeWithFont(f).offsetBy(13.0, 7.0)
		}

		return result
	}

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
