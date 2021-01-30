//
//  ZBreadcrumbButton.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/18/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

class ZBreadcrumbButton: ZButton, ZTooltips {

	var zone: Zone = gHere
	var currentEvent: ZEvent?

	var strokeColor: ZColor { // formerly indicated button visibility and corrected for colorful and dar modes
		let visible = zone.ancestralPath.contains(gHere)

		if  gColorfulMode {
			return visible ? gActiveColor .lighter(by: 4.0) : gAccentColor
		} else if  gIsDark {
			return visible ? kDarkGrayColor.darker(by: 6.0) : kDarkGrayColor.darker(by: 4.0)
		} else {
			return visible ? kDarkGrayColor.darker(by: 3.0) : kLightestGrayColor
		}
	}

	override func mouseDown(with event: ZEvent) {
		currentEvent = event
		super.mouseDown(with: event)
	}
	
}
