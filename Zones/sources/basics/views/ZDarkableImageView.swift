//
//  ZDarkableImageView.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/2/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

class ZDarkableImageView : ZImageView {

	var isDarkened = false

	override func draw(_ dirtyRect: NSRect) {
		if  isDarkened != gIsDark {
			isDarkened  = gIsDark
			image       = image?.invertedImage
		}

		super.draw(dirtyRect)
	}

}
