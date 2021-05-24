//
//  ZMapControlsView.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/15/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

enum ZModeButtonType: String {
	case tConfine = "browse"
	case tGrowth  = "grow"
}

class ZMapControlsView : ZButtonsView, ZTooltips {

	@IBOutlet var searchButton      : ZButton?
	override  var centered          : Bool { return true }
	override  var distributeEqually : Bool { return true }

	override func setupButtons() {
		removeButtons()

		buttons                   = [ZButton]()
		let t : [ZModeButtonType] = [.tGrowth, .tConfine]
		for type in t {
			let             title = type.rawValue
			let            button = ZButton(title: title, target: self, action: #selector(self.handleButtonPress))
			button.modeButtonType = type
			button.isBordered     = true

			button.setButtonType(.momentaryLight)
			buttons.append(button)
		}
	}

	override func updateButtons() {
		updateButtonTitlesAndColors()
		updateTooltips()
	}

	func updateButtonTitlesAndColors() {
		for button in buttons {
			if  let    type = button.modeButtonType {
				switch type {
					case .tConfine: button.title = gConfinementMode.rawValue
					case .tGrowth:  button.title = gListGrowthMode .rawValue
				}
			}

			(button.cell as? NSButtonCell)?.backgroundColor = gAccentColor
		}
	}

	@objc private func handleButtonPress(_ button: ZButton) {
		if  let    type = button.modeButtonType {
			switch type {
				case .tConfine: gConfinementMode = gBrowsingIsConfined ? .all : .list
				case .tGrowth:  gListGrowthMode  = gListsGrowDown      ? .up  : .down
			}
		}

		gSignal([.sDetails, .sCrumbs, .sRelayout])
	}

	func update() {
		updateButtonTitlesAndColors()
		setupAndRedraw()
		updateTooltips()
	}

}