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

	var strokeColor: ZColor {
		let visible = zone.ancestralPath.contains(gHere)

		if  gColorfulMode {
			return visible ? gActiveColor .lighter(by: 4.0) : gAccentColor
		} else if  gIsDark {
			return visible ? kDarkGrayColor.darker(by: 6.0) : kDarkGrayColor.darker(by: 4.0)
		} else {
			return visible ? kDarkGrayColor.darker(by: 3.0) : kLightestGrayColor
		}
	}

	override func draw(_ dirtyRect: NSRect) {
		if  gIsReadyToShowUI {
			let       name = zone.unwrappedName as NSString
			let       path = ZBezierPath(roundedRect: dirtyRect.insetEquallyBy(1.0), cornerRadius: 3.0)
			path.lineWidth = 2.0

			strokeColor.setStroke()
			strokeColor.setFill()
			path.stroke()
			path.fill()

			name.draw(in: dirtyRect.offsetBy(dx: 8.0, dy: -1.0), withAttributes: attributedTitle.attributes(at: 0, effectiveRange: nil))
		}
	}

	override func mouseDown(with event: ZEvent) {
		currentEvent = event
		super.mouseDown(with: event)
	}
	
}
