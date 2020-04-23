//
//  ZBreadcrumbButton.swift
//  Zones
//
//  Created by Jonathan Sand on 4/18/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZBreadcrumbButton: ZButton {

	var zone: Zone = gHere

	var strokeColor: ZColor {
		let ancestors = zone.ancestralPath
		let   visible = ancestors.contains(gHere)

		if !gColorfulMode {
			if gIsDark {
				return visible ? kDarkGrayColor.darker(by: 6.0) : kDarkGrayColor.darker(by: 4.0)
			} else {
				return visible ? kDarkGrayColor.darker(by: 3.0) : kLightestGrayColor
			}
		} else {
			return visible ? gActiveColor : gAccentColor
		}
	}

	override func draw(_ dirtyRect: NSRect) {
		if  gIsReadyToShowUI {
			let       path = ZBezierPath(roundedRect: dirtyRect.insetBy(dx: 1.0, dy: 1.0), cornerRadius: 3.0)
			path.lineWidth = 2.0

			strokeColor.setStroke()
			strokeColor.setFill()
			path.stroke()
			path.fill()

			(zone.unwrappedName as NSString).draw(in: dirtyRect.offsetBy(dx: 8.0, dy: -1.0), withAttributes: attributedTitle.attributes(at: 0, effectiveRange: nil))
		}
	}

	override func mouseMoved(with event: ZEvent) {
		print("hah!")
	}
	
}
