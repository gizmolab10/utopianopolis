//
//  ZHelpButtonsView.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/11/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZHelpButton : ZButton {

	override func draw(_ dirtyRect: NSRect) {
		let isCurrent =  helpMode == gCurrentHelpMode
		isHighlighted = isCurrent              // work around another pissy apple os bug!

		super.draw(dirtyRect)
	}

}

class ZHelpButtonsView : ZButtonsView {

	override  var centered : Bool { return true }
	var       isInTitleBar = false
	var         titleCount = 0

	func addButton(_ mode: ZHelpMode) -> ZHelpButton {
		let       title = mode.title.capitalized
		let      button = ZHelpButton(title: title, target: self, action: #selector(self.handleButtonPress))
		button.helpMode = mode

		buttons.append(button)

		return button
	}

	@discardableResult func buttonForMode(_ mode: ZHelpMode) -> ZButton {
		for button in buttons {
			if  button.helpMode == mode {
				return button
			}
		}

		return addButton(mode)
	}

	override func setupButtons() {
		for mode in gAllHelpModes {
			buttonForMode(mode)
		}
	}

	override func updateButtons() {
		for mode in gAllHelpModes {
			let    button = buttonForMode(      mode)
			let isCurrent = gCurrentHelpMode == mode

			if !isInTitleBar {
				button.isEnabled           = !isCurrent
			}
		}
	}

	@objc private func handleButtonPress(_ button: ZButton) {
		if  let mode = button.helpMode,
			mode    != gCurrentHelpMode {                   // eliminate no-op cpu time
			gHelpController?.show( true, nextMode: mode)    // side-effect: sets gCurrentHelpMode
			gSignal([.sStartupButtons])                     // to update help buttons in startup view
		}
	}

	func update() {
		updateAndRedraw()
	}

}
