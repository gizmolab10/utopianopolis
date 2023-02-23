//
//  ZMapControlsView.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/15/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

enum ZModeButtonType: String {
	case tBack    = "go back"
	case tForward = "go forward"
	case tConfine = "browse" // down / up
	case tGrowth  = "grow"   // list / all

	var image: ZImage {
		let direction = (self == .tBack) ? "left" : "right"

		return ZImage(named: direction)!
	}
}

var gMapControlsView : ZMapControlsView? { return gControlsController?.mapControlsView }

class ZMapControlsView : ZButtonsView, ZToolTipper {

	override func setupButtons() {
		super.setupButtons()

		buttons                   = [ZHoverableButton]()
		let t : [ZModeButtonType] = [.tBack, .tForward, .tGrowth, .tConfine]
		for type in t {
			let            button = buttonFor(type: type)
			button.modeButtonType = type
			button.isBordered     = true // ZDarkableImageButton

			button.setButtonType(.momentaryLight)
			buttons.append(button)
		}
	}

	func buttonFor(type: ZModeButtonType) -> ZButton {
		switch type {
			case .tGrowth, .tConfine:
				return ZHoverableButton(title:           type.rawValue, target: self, action: #selector(handleButtonPress))
			default:
				let button = ZDarkableImageButton(image: type.image,    target: self, action: #selector(handleButtonPress))

				button.setEnabledAndTracking(true)

				return button
		}
	}

	override func updateButtons() {
		updateButtonTitlesAndColors()
		updateToolTips(gModifierFlags)
	}

	func updateButtonTitlesAndColors() {
		for button in buttons {
			if  let    type = button.modeButtonType {
				switch type {
					case .tGrowth:  button.title = gListGrowthMode .rawValue
					case .tConfine: button.title = gConfinementMode.rawValue
					default:        break
				}
			}

			(button.cell as? NSButtonCell)?.backgroundColor = gAccentColor
		}
	}

	@objc private func handleButtonPress(_ button: ZButton) {
		gTextEditor.stopCurrentEdit(forceCapture: true) // don't discard user's work

		if  let    type = button.modeButtonType {
			let    down = type == .tForward
			switch type {
				case .tGrowth:  gListGrowthMode  = gListGrowthMode .next
				case .tConfine: gConfinementMode = gConfinementMode.next
				default:        go(down)
			}
		}

		gSignal([.sDetails])
	}

	func go(_ down: Bool) {
		if  gIsEssayMode {
			gEssayView?.nextNotemark(down: down)
		} else {
			gFavorites .nextBookmark(down: down, withinRecents: true)
		}
	}

	func controlsUpdate() {
		updateButtonTitlesAndColors()
		setupAndRedraw()
		updateToolTips(gModifierFlags)
	}

	override func draw(_ iDirtyRect: NSRect) {
		super.draw(iDirtyRect)

		if  buttons.count > 2 {
			let first = buttons[0].frame
			let  next = buttons[1].frame
			let width = next.minX - first.maxX
			let  size = CGSize(width: width, height: frame.height)
//			let  edge = CGSize(width:   1.0, height: frame.height)
			let   gap = CGRect(origin: CGPoint(x: first.maxX, y: .zero),       size: size)
//			let  left = CGRect(origin: .zero,                                  size: edge)
//			let right = CGRect(origin: CGPoint(x: frame.maxX - 1.0, y: .zero), size: edge)

			gap  .drawCenteredVerticalLine()
//			left .drawCenteredVerticalLine()
//			right.drawCenteredVerticalLine()
		}
	}

}
