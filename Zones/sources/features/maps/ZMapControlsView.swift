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
	case tDB      = "db"
}

class ZMapControlsView : ZButtonsView, ZTooltips {

	override  var centered          : Bool { return true }
	override  var distributeEqually : Bool { return true }

	override func setupButtons() {
		removeButtons()

		buttons                   = [ZButton]()
		let t : [ZModeButtonType] = [.tGrowth, .tConfine, .tDB]
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
					case .tDB:      button.title = gDatabaseID.mapControlString
				}
			}

			(button.cell as? NSButtonCell)?.backgroundColor = gAccentColor
		}
	}

	@objc private func handleButtonPress(_ button: ZButton) {
		if  let    type = button.modeButtonType {
			switch type {
				case .tConfine: gConfinementMode = gBrowsingIsConfined ? .all       : .list
				case .tGrowth:  gListGrowthMode  = gListsGrowDown      ? .up        : .down
				case .tDB:      swapDB()
			}
		}

		gSignal([.sDetails])
	}

	func swapDB() {
		gMapController?.toggleMaps()
		gRedrawMaps()
		gBreadcrumbsView?.setupAndRedraw()
	}

	func update() {
		updateButtonTitlesAndColors()
		setupAndRedraw()
		updateTooltips()
	}

}
