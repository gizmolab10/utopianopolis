//
//  ZDarkableImageButton.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/6/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class ZDarkableImageButton : ZButton {

	var original: ZImage?
	var darkened: ZImage?

	func setEnabledAndTracking(_ enabled: Bool) {
		isEnabled  = enabled
		isBordered = true
		bezelStyle = .texturedRounded

		setButtonType(.momentaryChange)
		setupAsDarkable()
	}

	func setupAsDarkable() {
		if  let        i  = image {
			if  darkened == nil {
				darkened  = i.invertedImage
				original  = i
			}

			image         = gIsDark ? darkened : original
		}
	}

}
