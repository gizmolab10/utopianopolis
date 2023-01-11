//
//  ZKickoffToolsController.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/28/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
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

var gKickoffToolsController: ZKickoffToolsController? { return gControllers.controllerForID(.idStartHere) as? ZKickoffToolsController }

enum ZKickoffToolID: String {
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
	case swapDB  = "swapDB"
	case option  = "option"
	case command = "command"
	case control = "control"
	case sibling = "sibling"
	case toolTip = "toolTip"
	case explain = "explain"
}

class ZKickoffToolsController: ZGenericController, ZToolTipper {

	override var controllerID : ZControllerID { return .idStartHere }
	var            isRelocate :   Bool { return flags.hasOption  && !gIsEditing }
	var               isMixed :   Bool { return flags.hasShift   && !gIsEditing && !flags.hasOption }
	var            canUnfocus :   Bool { return flags.hasControl && (gFavoritesRoot?.children.count ?? 0) > 1 }
	var             canTravel :   Bool { return gIsMapMode && gGrabbedCanTravel }
	var            swapDBText : String { return "switch to \(gIsMine ? "everyone's" : "my") ideas" }
	var           expandMaybe : String { return isMixed ? "expand selection " : kEmpty }
	var                 flags = ZEventFlags()
	var        buttonsByID    = [ZKickoffToolID  :  ZKickoffToolButton]()
	var          boxesByID    = [ZKickoffToolID  :  ZBox]()
	func       buttonFor(_ id :  ZKickoffToolID) -> ZKickoffToolButton? { return buttonsByID[id] }
	func          boxFor(_ id :  ZKickoffToolID) -> ZBox?               { return boxesByID  [id] }

	func updateBoxesAndButtons() {

		// provide useful hits about how behavior changes with work mode and modifier keys

		buttonFor(.control)?.isEnabled = !gIsSearching
		buttonFor(.option)? .isEnabled = !gIsSearching
		buttonFor(.shift)?  .isEnabled = !gIsSearching
		buttonFor(.focus)?  .isEnabled =  gIsMapMode
		buttonFor(.note)?   .isEnabled = !gIsEditIdeaMode
		boxFor   (.edit)?    .isHidden =  gIsSearching || gIsEssayMode
		boxFor   (.add)?     .isHidden =  gIsSearching || gIsEssayMode
		buttonFor(.swapDB)?     .title =  swapDBText
		buttonFor(.up)?         .title =  expandMaybe       + "up"
		buttonFor(.down)?       .title =  expandMaybe       + "down"
		buttonFor(.sibling)?    .title =  flags.hasOption    ? "parent"       : "sibling"
		buttonFor(.left)?       .title =  isMixed           ? "conceal"      : "left"
		buttonFor(.right)?      .title =  isMixed           ? "reveal"       : canTravel ? "invoke" : "right"
		buttonFor(.focus)?      .title =  canUnfocus        ? "unfocus"      : canTravel ? "invoke" : gSelecting.movableIsHere ? "favorite" : "focus"
		buttonFor(.toolTip)?    .title = (gShowToolTips     ? "hide"         : "show")   + " toolTips"
		buttonFor(.explain)?    .title = (gShowExplanations ? "hide"         : "show")   + " explains"
		boxFor   (.move)?       .title = (isRelocate        ? "Relocate"     : isMixed   ? "Mixed"  : "Browse") + (flags.hasCommand ? " to farthest"  : kEmpty)
		boxFor   (.edit)?       .title =  gIsEditing        ? "Stop Editing" : "Edit"
		buttonFor(.idea)?       .title =  "idea"
		buttonFor(.note)?       .title =  "note"
		buttonFor(.child)?      .title =  "child"
	}

	@IBAction func buttonAction(_ button: ZKickoffToolButton) {
		toolsUpdate()

		if  let itemID = button.kickoffToolID,
			let    key = keyFrom(itemID) {
			let isEdit = gIsEditIdeaMode && key.arrow != nil && flags.hasCommand
			var      f = flags

			switch key {
				case kSpace: if gIsEditIdeaMode { f.hasControl = true }  // so child will be created
				case "e",
					"y":     f.hasCommand = true                         // tweak because otherwise plain e / y is inserted into text
				default:     break
			}

			if  isEdit {
				f.hasCommand = false                                     // so browse does not go to extreme

				gTextEditor.stopCurrentEdit()                           // so browse ideas, not text
			}

			if  let m = gMainWindow, m.handleKey(key, flags: f) {       // this is so cool, ;-)
				FOREGROUND(after: 0.1) {
					if  isEdit {
						gSelecting.firstGrab()?.edit()                  // edit newly grabbed zone
					}

					gExplanation(showFor: key)
				}
			}
		}
	}

	override func controllerStartup() {

		// //////////////////////////////////// //
		// map buttons & boxes, using their ids //
		// //////////////////////////////////// //

		view.applyToAllSubviews { subview in
			if  let         box       = subview as? ZBox,
				let         boxID     = box.kickoffToolID {
				boxesByID  [boxID]    = box
			} else if let   button    = subview as? ZKickoffToolButton,
				let         buttonID  = button.kickoffToolID {
				buttonsByID[buttonID] = button

				setAutoRepeat(for: button)
			}
		}
	}

	func setAutoRepeat(for button: ZKickoffToolButton) {
		let autorepeaters: [ZKickoffToolID] = [.up, .down, .right, .left]
		if  let                    buttonID  = button.kickoffToolID,
			autorepeaters.contains(buttonID) {
			button.isContinuous              = true

			button.setPeriodicDelay(0.5, interval: 0.1)
		}
	}

	override func handleSignal(_ object: Any?, kind: ZSignalKind) {
		if  gDetailsViewIsVisible(for: .vKickoffTools) { // ignore if hidden
			toolsUpdate()
		}
	}

	func toolsUpdate() {
		updateFlags() // must call this first as others rely on flags
		updateToolTips(gModifierFlags)
		updateBoxesAndButtons()
	}

	func updateFlags() {
		flags.hasShift   = buttonFor(.shift)?  .state == NSControl.StateValue.on
		flags.hasOption  = buttonFor(.option)? .state == NSControl.StateValue.on
		flags.hasCommand = buttonFor(.command)?.state == NSControl.StateValue.on
		flags.hasControl = buttonFor(.control)?.state == NSControl.StateValue.on
	}

	func arrowFrom(_ from: ZKickoffToolID) -> ZArrowKey? {
		switch from {
			case .up:      return .up
			case .down:    return .down
			case .left:    return .left
			case .right:   return .right
			default:       return  nil
		}
	}

	func keyFrom(_ from: ZKickoffToolID) -> String? {
		switch from {
			case .note:    return "n"
			case .focus:   return "/"
			case .toolTip: return "y"
			case .explain: return "e"
			case .sibling: return kTab
			case .swapDB:  return kBackSlash
			case .child:   return kSpace
			case .idea:    return kReturn
			default:       return arrowFrom(from)?.key
		}
	}

}
