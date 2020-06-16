//
//  ZHelpButtonsView.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/11/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZHelpButtonsView : ZButtonsView {

	override  var centered : Bool { return true }
	var       isInTitleBar = false
	var         titleCount = 0

	override func setupButtons() {
		buttons   = [ZButton]()

		for mode in gAllHelpModes {
			let         title = mode.title.capitalized
			let        button = ZButton(title: title, target: self, action: #selector(self.handleButtonPress))
			button.buttonMode = mode

			buttons.append(button)

			if gCurrentHelpMode == mode {
				if !isInTitleBar {
					button.isEnabled = false
				} else {
					button.cell?.isHighlighted = true
				}
			}
		}
	}

	@objc private func handleButtonPress(_ button: ZButton) {
		if  let mode = button.buttonMode {
			gHelpController?.show(true, nextMode: mode)
			gSignal([.sStartup])
		}
	}

	func update() {
		updateAndRedraw()
	}

}
