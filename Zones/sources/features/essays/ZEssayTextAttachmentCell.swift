//
//  ZEssayTextAttachmentCell.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/4/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class ZEssayTextAttachmentCell: NSTextAttachmentCell {

	var darkened: ZImage?

	override var image: ZImage? {

		get {
			let original  = super.image
			if  darkened == nil {
				darkened  = original?.invertedImage
			}

			return gIsDark ? darkened : original
		}

		set {
			if  gIsDark {
				darkened    = newValue
				super.image = newValue?.invertedImage
			} else {
				super.image = newValue
				darkened    = newValue?.invertedImage
			}
		}

	}

}
