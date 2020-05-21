//
//  ZModeControlsView.swift
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
	case tAdd     = "add"
}

class ZModeControlsView : ZButtonsView, ZTooltips {

	override  var centered: Bool { return true }

	override func setupButtons() {
		let types: [ZModeButtonType] = [.tMode, .tAdd, .tGrow, .tConfine]
		buttons                      = [ZButton]()

		for type in types {
			let                 title = type.rawValue
			let                button = ZButton(title: title, target: self, action: #selector(self.handleButtonPress))
			button    .modeButtonType = type

			buttons.append(button)
		}

		updateButtonTitles()
		updateTooltips()
	}

	func updateButtonTitles() {
		for button in buttons {
			if  let    type = button.modeButtonType {
				switch type {
					case .tAdd:     button.title = "+"
					case .tMode:    button.title = gFavoritesMode  .rawValue
					case .tGrow:    button.title = gListGrowthMode .rawValue
					case .tConfine: button.title = gConfinementMode.rawValue
				}
			}
		}
	}

	@objc private func handleButtonPress(_ button: ZButton) {
		if  let    type = button.modeButtonType {
			switch type {
				case .tAdd:     gFavoritesHereMaybe?.addIdea()
				case .tMode:    gFavoritesMode   = gIsRecentlyMode     ? .favorites   : .recent
				case .tGrow:    gListGrowthMode  = gListsGrowDown      ? .up          : .down
				case .tConfine: gConfinementMode = gBrowsingIsConfined ? .all : .list
			}
		}

		updateButtonTitles()
		clearButtons()
		layoutButtons()
		updateTooltips()
		gSignal([.sRing, .sDetails, .sRelayout]) // remove sRing when eliminating recently view
	}

}
