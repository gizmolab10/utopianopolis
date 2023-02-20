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
	case tConfine = "browse" // down / up
	case tGrowth  = "grow"   // list / all
}

var gMapControlsView : ZMapControlsView? { return gControlsController?.mapControlsView }

class ZMapControlsView : ZButtonsView, ZToolTipper {

	override  var           centered : Bool { return true }
	override  var distributedEqually : Bool { return true }
	override  var  verticalLineIndex : Int? { return 1 }

	override func setupButtons() {
		super.setupButtons()

		buttons                   = [ZHoverableButton]()
		let t : [ZModeButtonType] = [.tGrowth, .tConfine]
		for type in t {
			let             title = type.rawValue
			let            button = ZHoverableButton(title: title, target: self, action: #selector(handleButtonPress))
			button.modeButtonType = type
			button.isBordered     = true

			button.setButtonType(.momentaryLight)
			buttons.append(button)
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
				case .tConfine: button.title = gConfinementMode.rawValue
				case .tGrowth:  button.title = gListGrowthMode .rawValue
				}
			}

			(button.cell as? NSButtonCell)?.backgroundColor = gAccentColor
		}
	}

	@objc private func handleButtonPress(_ button: ZButton) {
		gTextEditor.stopCurrentEdit(forceCapture: true) // don't discard user's work

		if  let    type = button.modeButtonType {
			switch type {
				case .tGrowth:  gListGrowthMode  = gListGrowthMode .next
				case .tConfine: gConfinementMode = gConfinementMode.next
			}
		}

		gSignal([.sDetails])
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
