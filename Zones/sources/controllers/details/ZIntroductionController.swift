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

// simple wrapper GUI for graph editor's handle key/arrow

class ZIntroductionController: ZGenericController {

	override var controllerID : ZControllerID { return .idIntroduction }
	var                 flags = ZEventFlags()
	var            showMeDown = false
	var        buttonsByID    = [ZIntroductionID  :  ZButton]()
	var          boxesByID    = [ZIntroductionID  :  ZBox]()
	func       buttonFor(_ id :  ZIntroductionID) -> ZButton? { return buttonsByID[id] }
	func          boxFor(_ id :  ZIntroductionID) -> ZBox?    { return boxesByID  [id] }

	override func startup() {
		view.applyToAllSubviews { subview in
			if  let       button = subview as? ZButton,
				let     buttonID = button.introductionID {
				buttonsByID[buttonID] = button
			} else if let    box = subview as? ZBox,
				let        boxID = box.introductionID {
				boxesByID[boxID] = box
			}
		}
	}

	override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		update()
	}

	func update() {
		let               showHide =  flags.isShift && !flags.isOption
		buttonFor(.left)?   .title =  showHide        ? "hide"       : "left"
		buttonFor(.right)?  .title =  showHide        ? "show"       : "right"
		buttonFor(.focus)?  .title =  flags.isControl ? "unfocus"    : "focus"
		buttonFor(.sibling)?.title =  flags.isOption  ? "add parent" : "add sibling"
		boxFor   (.move)?   .title = (flags.isOption  ? "Relocate"   : flags.isShift ? "Show/Hide" : "Browse") + (flags.isCommand ? " to end" : "")
	}

	func updateFlags() {
		flags.isShift   = buttonFor(.shift)?  .state == NSControl.StateValue.on
		showMeDown      = buttonFor(.showMe)? .state == NSControl.StateValue.on
		flags.isOption  = buttonFor(.option)? .state == NSControl.StateValue.on
		flags.isCommand = buttonFor(.command)?.state == NSControl.StateValue.on
		flags.isControl = buttonFor(.control)?.state == NSControl.StateValue.on
	}

	@IBAction func buttonAction(_ button: ZButton) {
		if  let  itemID = button.introductionID {
			updateFlags()
			update()

			if  let key = keyFrom(itemID) {
				gGraphEditor.handleKey(key, flags: flags, isWindow: true)
			} else if let arrow = arrowFrom(itemID) {
				gGraphEditor.handleArrow(arrow, flags: flags)
			}
		}
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

}
