//
//  ZIntroductionButton.swift
//  Zones
//
//  Created by Jonathan Sand on 5/4/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZIntroductionButton: ZButton {

	@IBOutlet var controller: ZIntroductionController?
	var downTitle = ""
	var   upTitle = ""

	override func awakeFromNib() {
		downTitle = alternateTitle
		upTitle   = title

		let options = [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInKeyWindow, NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.inVisibleRect] as NSTrackingArea.Options
		let tracker = NSTrackingArea(rect:frame, options: options, owner:self, userInfo: nil)
		addTrackingArea(tracker)
	}

	func updateTitleForDown(_ down: Bool) {
		title = down ? downTitle : upTitle
	}

	override func mouseDown(with event: NSEvent) {
		updateTitleForDown(true)
		super.mouseDown(with: event)
	}

	override func mouseUp(with event: NSEvent) {
		updateTitleForDown(false)
		controller?.update()
		super.mouseUp(with: event)
	}

	override func mouseExited(with event: NSEvent) {
		updateTitleForDown(false)
		controller?.update()
		super.mouseExited(with: event)
	}

}
