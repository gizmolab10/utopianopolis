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

	override func draw(_ dirtyRect: NSRect) {
		if  gIsReadyToShowUI {
			let   ancestors = zone.ancestralPath
			let     visible = ancestors.contains(gHere)
			let        path = ZBezierPath(roundedRect: dirtyRect.insetBy(dx: 1.0, dy: 1.0), cornerRadius: 3.0)
			let strokeColor = visible ? gActiveColor : gAccentColor
			let   fillColor = isHighlighted ? strokeColor : strokeColor.lighter(by: 4.0)
			path .lineWidth = 2.0

			strokeColor.setStroke()
			fillColor.setFill()
			path.stroke()
			path.fill()

			(zone.unwrappedName as NSString).draw(in: dirtyRect.offsetBy(dx: 8.0, dy: -1.0), withAttributes: attributedTitle.attributes(at: 0, effectiveRange: nil))
		}
	}

	override func mouseMoved(with event: ZEvent) {
		print("hah!")
	}
	
}
