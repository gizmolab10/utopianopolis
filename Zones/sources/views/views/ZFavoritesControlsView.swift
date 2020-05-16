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
		let types: [ZFavoritesControlType] = [.eMode, .eAdd, .eGrowth, .eConfinement]
		buttons                            = [ZButton]()

		for type in types {
			let                      title = type.rawValue
			let                     button = ZButton(title: title, target: self, action: #selector(self.handleButtonPress))
			button   .favoritesControlType = type

			buttons.append(button)
		}

		updateTooltips()
	}

	@objc private func handleButtonPress(_ button: ZButton) {
		if  let    type = button.favoritesControlType {
			switch type {
				case .eAdd:         gFavoritesHereMaybe?.addIdea()
				case .eMode:        rotateMode()
				case .eGrowth:      gListGrowthMode = gListsGrowDown      ? .up          : .down
				case .eConfinement: gBrowsingMode   = gBrowsingIsConfined ? .cousinJumps : .confined
			}
		}

		updateTooltips()
		gSignal([.sRing])
	}

	func rotateMode() {

	}

}
