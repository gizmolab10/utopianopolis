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
	var  current: ZImage? { return gIsDark ? darkened : original }

	func setEnabledAndTracking(_ enabled: Bool) {
		isEnabled  = enabled
		isBordered = true
		bezelStyle = .texturedRounded

		setButtonType(.momentaryChange)
		setupAsDarkable()

		image      = current
	}

	func setupAsDarkable() {
		if  darkened == nil {
			darkened  = image?.invertedImage
			original  = image
		}
	}

}
