//
//  ZDarkableImage.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/4/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

class ZDarkableImage : ZImage {

	var darkened: ZImage?

	var current: ZImage? {
		setupAsDarkable()

		return gIsDark ? darkened : self as ZImage
	}

	open override func draw(in rect: NSRect) {
		current?.draw(in: rect)
	}

	func setupAsDarkable() {
		if  darkened     == nil,
			let  darkable = invertedImage {
			darkable.size = size
			darkened      = darkable
		}
	}

	static func create(from image: ZImage) -> ZDarkableImage? {
		if  let    darkable = image as? ZDarkableImage {
			return darkable
		}

		if  let        data = image.tiffRepresentation {
			let      result = ZDarkableImage(data: data)

			result?.setupAsDarkable()

			return   result
		}

		return nil
	}

}
