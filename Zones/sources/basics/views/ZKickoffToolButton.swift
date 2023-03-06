//
//  ZKickoffToolButton.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/4/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

class ZKickoffToolButton: ZHoverableButton {

	@IBOutlet var controller: ZKickoffToolsController?
	var downTitle = kEmpty
	var   upTitle = kEmpty

	override var debugName: String { return title }

	override func awakeFromNib() {
		downTitle = alternateTitle.isEmpty ? title : alternateTitle
		upTitle   = title

		updateTracking()
	}

	func updateTitleForDown(_ down: Bool) {
		title = down ? downTitle : upTitle
	}

	override func mouseDown(with event: ZEvent) {
		updateTitleForDown(true)
		super.mouseDown(with: event)
	}

	override func mouseUp(with event: ZEvent) {
		updateTitleForDown(false)
		controller?.toolsUpdate()
		super.mouseUp(with: event)
	}

	override func mouseExited(with event: ZEvent) {
		updateTitleForDown(false)
		controller?.toolsUpdate()
		super.mouseExited(with: event)
	}

}
