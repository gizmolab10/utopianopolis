//
//  ZIntroductionController.swift
//  Zones
//
//  Created by Jonathan Sand on 4/28/20.
//  Copyright © 2020 Zones. All rights reserved.
//

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

enum ZIntroductionButtonID: String {
	case child   = "child"
	case sibling = "sibling"
	case idea    = "idea"
	case note    = "note"
	case up      = "up"
	case down    = "down"
	case left    = "left"
	case right   = "right"
	case focus   = "focus"
	case shift   = "shift"
	case command = "command"
	case option  = "option"
	case control = "control"
	case showMe  = "showMe"
}

class ZIntroductionController: ZGenericController {

	@IBOutlet var        addBox : ZBox?
	@IBOutlet var       editBox : ZBox?
	@IBOutlet var       moveBox : ZBox?
	@IBOutlet var    leftButton : ZButton?
	@IBOutlet var   rightButton : ZButton?
	@IBOutlet var   focusButton : ZButton?
	@IBOutlet var   shiftButton : ZButton?
	@IBOutlet var  showMeButton : ZButton?
	@IBOutlet var  optionButton : ZButton?
	@IBOutlet var commandButton : ZButton?
	@IBOutlet var controlButton : ZButton?
	@IBOutlet var siblingButton : ZButton?
	override  var  controllerID : ZControllerID { return .idIntroduction }
	var             commandDown = false
	var             controlDown = false
	var              optionDown = false
	var              showMeDown = false
	var               shiftDown = false

	@IBAction func buttonAction(_ button: NSUserInterfaceItemIdentification) {
		if  let  identifier = button.identifier?.rawValue,
			let    buttonID = ZIntroductionButtonID(rawValue: identifier) {
			let        zone = gSelecting.currentMoveable
			switch buttonID {
				case .child:   zone.addIdea()
				case .sibling: zone.addNext()
				case .idea:    zone.edit()
				case .note:    break
				case .up:      break
				case .down:    break
				case .left:    break
				case .right:   break
				case .focus:   break
				default:       break
			}

			shiftDown   = shiftButton?  .state == NSControl.StateValue.on
			showMeDown  = showMeButton? .state == NSControl.StateValue.on
			optionDown  = optionButton? .state == NSControl.StateValue.on
			commandDown = commandButton?.state == NSControl.StateValue.on
			controlDown = controlButton?.state == NSControl.StateValue.on

			update()
		}
	}

	func update() {
		leftButton?   .title =  shiftDown   ? "conceal"    : "left"
		rightButton?  .title =  shiftDown   ? "reveal"     : "right"
		focusButton?  .title = controlDown  ? "unfocus"    : "focus"
		siblingButton?.title =  optionDown  ? "add parent" : "add sibling"
		moveBox?      .title = (optionDown  ? "Relocate"   : "Browse") + (commandDown ? " to end" : "")
	}

	override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		update()
	}

}
