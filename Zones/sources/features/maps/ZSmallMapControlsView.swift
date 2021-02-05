//
//  ZSmallMapControlsView.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/15/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

enum ZModeButtonType: String {
	case tConfine = "browse"
	case tGrow    = "grow"
	case tMode    = "mode"
}

class ZSmallMapControlsView : ZButtonsView, ZTooltips {

	override  var centered: Bool { return true }

	override func setupButtons() {
		removeButtons()

		buttons                   = [ZButton]()
		let t : [ZModeButtonType] = [.tMode, .tGrow, .tConfine]
		for type in t {
			let             title = type.rawValue
			let            button = ZButton(title: title, target: self, action: #selector(self.handleButtonPress))
			button.modeButtonType = type

			buttons.append(button)
		}
	}

	override func updateButtons() {
		updateButtonTitles()
		updateTooltips()
	}

	func updateButtonTitles() {
		for button in buttons {
			if  let    type = button.modeButtonType {
				switch type {
					case .tConfine: button.title = gConfinementMode.rawValue
					case .tGrow:    button.title = gListGrowthMode .rawValue
					case .tMode:    button.title = "Switch"
				}
			}
		}
	}

	@objc private func handleButtonPress(_ button: ZButton) {
		if  let    type = button.modeButtonType {
			switch type {
				case .tMode:    gSmallMapMode    = gIsRecentlyMode     ? .favorites : .recent
				case .tGrow:    gListGrowthMode  = gListsGrowDown      ? .up        : .down
				case .tConfine: gConfinementMode = gBrowsingIsConfined ? .all       : .list
			}
		}

		gSignal([.sDetails])
	}

	func update() {
		updateButtonTitles()
		setupAndRedraw()
		updateTooltips()
	}

}
