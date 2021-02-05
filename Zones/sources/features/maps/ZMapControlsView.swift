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
	case tGrow    = "grow"
	case tDB      = "db"
}

class ZMapControlsView : ZButtonsView, ZTooltips {

	override  var centered: Bool { return true }

	override func setupButtons() {
		removeButtons()

		buttons                   = [ZButton]()
		let t : [ZModeButtonType] = [.tGrow, .tConfine, .tDB]
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
					case .tDB:      button.title = gDatabaseID.identifier
				}
			}
		}
	}

	@objc private func handleButtonPress(_ button: ZButton) {
		if  let    type = button.modeButtonType {
			switch type {
				case .tConfine: gConfinementMode = gBrowsingIsConfined ? .all       : .list
				case .tGrow:    gListGrowthMode  = gListsGrowDown      ? .up        : .down
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
		updateButtonTitles()
		setupAndRedraw()
		updateTooltips()
	}

}
