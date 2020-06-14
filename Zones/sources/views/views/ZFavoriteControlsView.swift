//
//  ZFavoriteControlsView.swift
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

class ZFavoriteControlsView : ZButtonsView, ZTooltips {

	override  var centered: Bool { return true }

	override func setupButtons() {
		var types: [ZModeButtonType] = [.tMode, .tGrow, .tConfine]
		buttons                      = [ZButton]()

		if !gIsRecentlyMode {
			types.insert(.tAdd, at: 1)
		}

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
					case .tConfine: button    .title = gConfinementMode.rawValue
					case .tMode:    button    .title = "Show \(gIsRecentlyMode ? "Favorites" : "Recent")"
					case .tGrow:    button    .title = gListGrowthMode .rawValue
					case .tAdd:     button    .title = "+"
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

		gSignal([.sFavorites, .sDetails])
	}

	func update() {
		updateButtonTitles()
		updateAndRedraw()
		updateTooltips()
	}

}
