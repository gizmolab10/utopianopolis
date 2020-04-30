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

enum ZIntroductionID: String {
	case up      = "up"
	case add     = "add"
	case edit    = "edit"
	case move    = "move"
	case idea    = "idea"
	case note    = "note"
	case down    = "down"
	case left    = "left"
	case child   = "child"
	case right   = "right"
	case focus   = "focus"
	case shift   = "shift"
	case showMe  = "showMe"
	case option  = "option"
	case command = "command"
	case control = "control"
	case sibling = "sibling"
}

class ZIntroductionController: ZGenericController {

	override  var  controllerID : ZControllerID { return .idIntroduction }
	var             commandDown = false
	var             controlDown = false
	var              optionDown = false
	var              showMeDown = false
	var               shiftDown = false
	var buttonsByID = [ZIntroductionID : ZButton]()
	var   boxesByID = [ZIntroductionID : ZBox]()
	func buttonFor(_ id: ZIntroductionID) -> ZButton? { return buttonsByID[id] }
	func    boxFor(_ id: ZIntroductionID) -> ZBox?    { return boxesByID  [id] }

	var currentFlags: ZEventFlags {
		var       flags = ZEventFlags()
		flags.isCommand = commandDown
		flags.isControl = controlDown
		flags.isOption  = optionDown
		flags.isShift   = shiftDown

		return flags
	}

	override func awakeFromNib() {
		super.awakeFromNib()

		view.applyToAllSubviews { subview in
			if  let       button = subview as? ZButton,
				let     buttonID = idForItem(button) {
				buttonsByID[buttonID] = button
			} else if let    box = subview as? ZBox,
				let        boxID = idForItem(box) {
				boxesByID[boxID] = box
			}
		}
	}

	func idForItem(_ item: NSUserInterfaceItemIdentification) -> ZIntroductionID? {
		if  let identifier = item.identifier?.rawValue,
			let     itemID = ZIntroductionID(rawValue: identifier) {
			return  itemID
		}

		return nil
	}

	func arrowFrom(_ from: ZIntroductionID) -> ZArrowKey? {
		switch from {
			case .up:    return .up
			case .down:  return .down
			case .left:  return .left
			case .right: return .right
			default:     return  nil
		}
	}

	func keyFrom(_ from: ZIntroductionID) -> String? {
		switch from {
			case .child:   return kSpace
			case .sibling: return kTab
			case .idea:    return kReturn
			case .note:    return "n"
			case .focus:   return "/"
			default:       return nil
		}
	}

	@IBAction func buttonAction(_ button: ZButton) {
		if  let buttonID = idForItem(button) {
			let    flags = currentFlags

			if  let  key = keyFrom(buttonID) {
				gGraphEditor.handleKey(key, flags: flags, isWindow: true)
			} else if let arrow = arrowFrom(buttonID) {
				gGraphEditor.handleArrow(arrow, flags: currentFlags)
			}

			shiftDown   = buttonFor(.shift)?  .state == NSControl.StateValue.on
			showMeDown  = buttonFor(.showMe)? .state == NSControl.StateValue.on
			optionDown  = buttonFor(.option)? .state == NSControl.StateValue.on
			commandDown = buttonFor(.command)?.state == NSControl.StateValue.on
			controlDown = buttonFor(.control)?.state == NSControl.StateValue.on

			update()
		}
	}

	func update() {
		let               showHide =  shiftDown && !optionDown
		buttonFor(.left)?   .title =  showHide   ? "hide"       : "left"
		buttonFor(.right)?  .title =  showHide   ? "show"       : "right"
		buttonFor(.focus)?  .title = controlDown ? "unfocus"    : "focus"
		buttonFor(.sibling)?.title =  optionDown ? "add parent" : "add sibling"
		boxFor(.move)?      .title = (optionDown ? "Relocate"   : shiftDown ? "Show/Hide" : "Browse") + (commandDown ? " to end" : "")
	}

	override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		update()
	}

}
