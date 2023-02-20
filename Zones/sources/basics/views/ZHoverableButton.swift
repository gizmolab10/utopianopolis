//
//  ZHoverableButton.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/13/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class ZHoverableButton: ZDarkableImageButton, ZToolTipper {

	var originalBackgroundColor: ZColor?

	override var size: CGSize {
		var result = frame.size
		if  let  f = font, image == nil {
			result = title.sizeWithFont(f).offsetBy(13.0, 7.0)
		}

		return result
	}

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