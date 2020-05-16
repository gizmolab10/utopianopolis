//
//  ZFavoritesControlsView.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/15/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZFavoritesControlsView : ZButtonsView {

	override func setupButtons() {
		buttons = [ZButton]()
		let types: [ZFavoritesControlType] = [.eMode, .eAdd, .eGrowth, .eConfinement]

		for type in types {
			let button = ZButton(title: type.rawValue, target: self, action: #selector(self.handleButtonPress))

			buttons.append(button)
		}
	}

	@objc private func handleButtonPress(_ iButton: ZButton) {
	}

}
