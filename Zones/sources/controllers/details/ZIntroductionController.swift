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

// ////////////////////////////////////////////////////// //
//                                                        //
//  simple wrapper GUI for various editors' key handling  //
//       with hints to user about keyboard shortcuts      //
//                                                        //
// ////////////////////////////////////////////////////// //

class ZIntroductionController: ZGenericController {

	override var controllerID : ZControllerID { return .idIntroduction }
	var                 flags = ZEventFlags()
	var        buttonsByID    = [ZIntroductionID  :  ZIntroductionButton]()
	var          boxesByID    = [ZIntroductionID  :  ZBox]()
	func       buttonFor(_ id :  ZIntroductionID) -> ZIntroductionButton? { return buttonsByID[id] }
	func          boxFor(_ id :  ZIntroductionID) -> ZBox?                { return boxesByID  [id] }

	func update() {

		// provide useful hits about how behavior changes with work mode and modifier keys

		if  let                          c =  gDetailsController, !c.hideableIsHidden(for: .Introduction),    // don't update a hidden introductions controller
		    let                       zone =  gSelecting.currentMovableMaybe {
			let                     isHere =  zone == gHere
			let                  canTravel =  gIsGraphMode && zone.canTravel
			let                  isEditing =  gIsEditIdeaMode || gIsNoteMode
			let                   showHide =  flags.isShift && !flags.isOption
			buttonFor(.control)?.isEnabled = !gIsSearchMode
			buttonFor(.option)? .isEnabled = !gIsSearchMode
			buttonFor(.shift)?  .isEnabled = !gIsSearchMode
			buttonFor(.focus)?  .isEnabled =  gIsGraphMode
			buttonFor(.note)?   .isEnabled = !gIsEditIdeaMode
			boxFor   (.edit)?    .isHidden =  gIsSearchMode || gIsNoteMode
			boxFor   (.add)?     .isHidden =  gIsSearchMode || gIsNoteMode
			buttonFor(.sibling)?    .title =  flags.isOption  ? "parent"       : "sibling"
			buttonFor(.left)?       .title =  showHide        ? "hide"         : "left"
			buttonFor(.right)?      .title =  showHide        ? "show"         : canTravel     ? "travel"    : "right"
			buttonFor(.focus)?      .title =  flags.isControl ? "unfocus"      : canTravel     ? "travel"    :                       isHere ? "favorite" : "focus"
			boxFor   (.move)?       .title = (flags.isOption  ? "Relocate"     : flags.isShift ? "Show/Hide" : "Browse") + (flags.isCommand ? " to end"  : "")
			boxFor   (.edit)?       .title =  isEditing       ? "Stop Editing" : "Edit"
		}
	}

	@IBAction func buttonAction(_ button: ZIntroductionButton) {
		updateFlags()
		update()

		if  let itemID = button.introductionID,
			let    key = keyFrom(itemID) {

			gWindow?.handleKey(key, flags: flags)    // this is so cool, ;-)
		}
	}

	override func startup() {

		// //////////////////////////////////// //
		// map buttons & boxes, using their ids //
		// //////////////////////////////////// //

		view.applyToAllSubviews { subview in
			if  let            box    = subview as? ZBox,
				let            boxID  = box.introductionID {
				boxesByID     [boxID] = box
			} else if let   button    = subview as? ZIntroductionButton,
				let         buttonID  = button.introductionID {
				buttonsByID[buttonID] = button
				button  .isContinuous = true

				button.setPeriodicDelay(0.5, interval: 0.1)
			}
		}
	}

	override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		update()
	}

	func updateFlags() {
		flags.isShift   = buttonFor(.shift)?  .state == NSControl.StateValue.on
		flags.isOption  = buttonFor(.option)? .state == NSControl.StateValue.on
		flags.isCommand = buttonFor(.command)?.state == NSControl.StateValue.on
		flags.isControl = buttonFor(.control)?.state == NSControl.StateValue.on
	}

	func arrowFrom(_ from: ZIntroductionID) -> ZArrowKey? {
		switch from {
			case .up:      return .up
			case .down:    return .down
			case .left:    return .left
			case .right:   return .right
			default:       return  nil
		}
	}

	func keyFrom(_ from: ZIntroductionID) -> String? {
		switch from {
			case .child:   return kSpace
			case .sibling: return kTab
			case .idea:    return kReturn
			case .note:    return "n"
			case .focus:   return "/"
			default:       return arrowFrom(from)?.key
		}
	}

}
