//
//  ZHelpButtonsView.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/11/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZHelpButton : ZButton {

	var helpButtonsView : ZHelpButtonsView?

	override func draw(_ dirtyRect: NSRect) {
		let isInTitle = helpButtonsView?.isInTitleBar ?? false
		let isCurrent = isInTitle && helpMode == gCurrentHelpMode
		isHighlighted = isCurrent              // work around another pissy apple os bug!

		super.draw(dirtyRect)
	}

}

class ZHelpButtonsView : ZButtonsView {

	override  var centered : Bool { return true }
	var       isInTitleBar = false
	var         titleCount = 0

	func addButton(_ mode: ZHelpMode) -> ZHelpButton {
		let              title = mode.title.capitalized
		let             button = ZHelpButton(title: title, target: self, action: #selector(self.handleButtonPress))
		button.helpMode        = mode
		button.helpButtonsView = self

		buttons.append(button)

		return button
	}

	@discardableResult func buttonForMode(_ mode: ZHelpMode) -> ZButton {
		for button in buttons {
			if  button.helpMode == mode {
				return button
			}
		}

		return addButton(mode)
	}

	override func setupButtons() {
		for mode in gAllHelpModes {
			buttonForMode(mode)
		}
	}

	override func updateButtons() {
		for mode in gAllHelpModes {
			buttonForMode(mode).isEnabled = true
		}
	}

	@objc private func handleButtonPress(_ button: ZButton) {
		if  let mode = button.helpMode { // eliminate no-op cpu time
			gHelpController?.showHelp(for: mode)
		}
	}

	func actuateNextButton(forward: Bool) {
		var    mode = gCurrentHelpMode
		switch mode {
			case .basicMode:  mode = forward ? .mediumMode : .dotMode
			case .mediumMode: mode = forward ? .allMode    : .basicMode
			case .allMode:    mode = forward ? .essayMode  : .mediumMode
			case .essayMode:  mode = forward ? .dotMode    : .allMode
			case .dotMode:    mode = forward ? .basicMode  : .essayMode
			default:          break
		}

		gHelpController?.showHelp(for: mode)
	}

	func update() {
		updateAndRedraw()
	}

}
