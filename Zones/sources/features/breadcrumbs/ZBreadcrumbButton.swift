//
//  ZBreadcrumbButton.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/18/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

class ZBreadcrumbButton: ZHoverableButton {

	var                   zone = gHere
	var currentBreadcrumbEvent : ZEvent?
	override var     debugName : String { return zone.debugName }

	override func mouseDown(with event: ZEvent) {
		currentBreadcrumbEvent = event

		super.mouseDown(with: event)
	}

}
