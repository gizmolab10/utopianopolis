//
//  ZFavoritesControlsView.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/15/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZFavoritesControlsView : ZButtonsView, ZTooltips {

	override  var centered: Bool { return true }

	override func setupButtons() {
		let types: [ZFavoritesControlType] = [.eMode, .eAdd, .eGrowth, .eConfining]
		buttons                            = [ZButton]()

		for type in types {
			let                      title = type.rawValue
			let                     button = ZButton(title: title, target: self, action: #selector(self.handleButtonPress))
			button   .favoritesControlType = type

			buttons.append(button)
		}

		updateButtonTitles()
		updateTooltips()
	}

	func updateButtonTitles() {
		for button in buttons {
			if let type = button.favoritesControlType {
				switch type {
					case .eAdd:       button.title = "+"
					case .eMode:      button.title = gFavoritesModeIsRecently ? "Recent" : "Favorites"
					case .eGrowth:    button.title = gListsGrowDown           ? "Bottom" : "Top"
					case .eConfining: button.title = gBrowsingIsConfined      ? "List"   : "All"
				}
			}
		}
	}

	@objc private func handleButtonPress(_ button: ZButton) {
		if  let    type = button.favoritesControlType {
			switch type {
				case .eAdd:       gFavoritesHereMaybe?.addIdea()
				case .eMode:      gFavoritesMode  = gFavoritesModeIsRecently ? .favorites   : .recently
				case .eGrowth:    gListGrowthMode = gListsGrowDown           ? .up          : .down
				case .eConfining: gBrowsingMode   = gBrowsingIsConfined      ? .cousinJumps : .confined
			}
		}

		updateButtonTitles()
		clearButtons()
		layoutButtons()
		updateTooltips()
		gSignal([.sRing]) // remove this when eliminating recently view
	}

}
