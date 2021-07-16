//
//  ZBreadcrumbButton.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/18/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

class ZBreadcrumbButton: ZTooltipButton {

	var         zone : Zone = gHere
	var currentEvent : ZEvent?

	override func mouseDown(with event: ZEvent) {
		currentEvent = event

		super.mouseDown(with: event)
	}

}
