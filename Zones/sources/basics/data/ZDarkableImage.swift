//
//  ZDarkableImage.swift
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

class ZDarkableImage : ZImage {

	var original: ZImage?
	var darkened: ZImage?

	var current: ZImage? {
		return (gIsDark ? darkened : original) ?? self as ZImage
	}

	func setupAsDarkable() {
		if  darkened       == nil,
			let darkable    = invertedImage {
			darkable.size   = size
			darkened        = darkable
			original        = self
		}
	}

	static func create(from   image: ZImage?) -> ZDarkableImage? {
		if  let    darkable = image          as? ZDarkableImage {
			return darkable   // already created it
		}

		if  let    data     = image?.tiffRepresentation {
			let    result   = ZDarkableImage(data: data)

			result?.setupAsDarkable()

			return result
		}

		return nil
	}

}
