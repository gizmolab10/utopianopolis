//
//  ZHelpButtonsView.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/11/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZHelpButtonsView : ZButtonsView {

	override  var centered: Bool { return true }

	override func setupButtons() {
		let modes: [ZWorkMode] = [.graphMode, .noteMode, .dotMode]
		buttons                = [ZButton]()

		for mode in modes {
			let          title = mode.title
			let         button = ZButton(title: title, target: self, action: #selector(self.handleButtonPress))
			button.buttonMode  = mode

			buttons.append(button)
		}
	}

	@objc private func handleButtonPress(_ button: ZButton) {
		if  let    mode = button.buttonMode {
			gShortcutsController?.show(true, nextMode: mode)
		}
	}

	func update() {
		updateAndRedraw()
	}

}
