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

var gKickoffToolsController: ZKickoffToolsController? { return gControllerForID(.idStartHere) as? ZKickoffToolsController }

enum ZKickoffToolID: String {

	case tUp      = "up"
	case tAdd     = "add"
	case tEdit    = "edit"
	case tMove    = "move"
	case tIdea    = "idea"
	case tNote    = "note"
	case tDown    = "down"
	case tLeft    = "left"
	case tChild   = "child"
	case tRight   = "right"
	case tFocus   = "focus"
	case tShift   = "shift"
	case tSwapDB  = "swapDB"
	case tOption  = "option"
	case tCommand = "command"
	case tControl = "control"
	case tSibling = "sibling"
	case tToolTip = "toolTip"
	case tExplain = "explain"

	var arrow: ZArrowKey? {
		switch self {
			case .tUp:      return .up
			case .tDown:    return .down
			case .tLeft:    return .left
			case .tRight:   return .right
			default:        return  nil
		}
	}

	var key: String? {
		switch self {
			case .tExplain: return "e"
			case .tNote:    return "n"
			case .tToolTip: return "y"
			case .tSibling: return kTab
			case .tChild:   return kSpace
			case .tFocus:   return kSlash
			case .tIdea:    return kReturn
			case .tSwapDB:  return kBackSlash
			default:        return arrow?.key
		}
	}

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

		buttonFor(.tControl)?.isEnabled = !gIsSearching
		buttonFor(.tOption)? .isEnabled = !gIsSearching
		buttonFor(.tShift)?  .isEnabled = !gIsSearching
		buttonFor(.tFocus)?  .isEnabled =  gIsMapMode
		buttonFor(.tNote)?   .isEnabled = !gIsEditIdeaMode
		boxFor   (.tEdit)?    .isHidden =  gIsSearching || gIsEssayMode
		boxFor   (.tAdd)?     .isHidden =  gIsSearching || gIsEssayMode
		buttonFor(.tSwapDB)?     .title =  swapDBText
		buttonFor(.tUp)?         .title =  expandMaybe       + "up"
		buttonFor(.tDown)?       .title =  expandMaybe       + "down"
		buttonFor(.tSibling)?    .title =  flags.hasOption    ? "parent"       : "sibling"
		buttonFor(.tLeft)?       .title =  isMixed           ? "conceal"      : "left"
		buttonFor(.tRight)?      .title =  isMixed           ? "reveal"       : canTravel ? "invoke" : "right"
		buttonFor(.tFocus)?      .title =  canUnfocus        ? "unfocus"      : canTravel ? "invoke" : gSelecting.movableIsHere ? "favorite" : "focus"
		buttonFor(.tToolTip)?    .title = (gShowToolTips     ? "hide"         : "show")   + " toolTips"
		buttonFor(.tExplain)?    .title = (gShowExplanations ? "hide"         : "show")   + " explains"
		boxFor   (.tMove)?       .title = (isRelocate        ? "Relocate"     : isMixed   ? "Mixed"  : "Browse") + (flags.hasCommand ? " to farthest"  : kEmpty)
		boxFor   (.tEdit)?       .title =  gIsEditing        ? "Stop Editing" : "Edit"
		buttonFor(.tIdea)?       .title =  "idea"
		buttonFor(.tNote)?       .title =  "note"
		buttonFor(.tChild)?      .title =  "child"
	}

	@IBAction func buttonAction(_ button: ZKickoffToolButton) {
		toolsUpdate()

		if  let itemID = button.kickoffToolID,
			let    key = itemID.key {
			let isEdit = gIsEditIdeaMode && key.arrow != nil && flags.hasCommand
			var      f = flags

			switch key {
				case kSpace: if gIsEditIdeaMode { f.hasControl = true }  // so child will be created
				case "e",
					 "y":    f.hasCommand = true                         // tweak because otherwise plain e / y is inserted into text
				default:     break
			}

			if  isEdit {
				f.hasCommand = false                                     // so browse does not go to extreme

				gTextEditor.stopCurrentEdit()                            // so browse ideas, not text
			}

			if  let m = gMainWindow, m.handleKeyInMainWindow(key, flags: f) {        // this is so cool, ;-)
				FOREGROUND(after: 0.1) {
					if  isEdit {
						gSelecting.firstGrab()?.edit()                   // edit newly grabbed zone
						gRelayoutMaps()
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
		let autorepeaters: [ZKickoffToolID] = [.tUp, .tDown, .tRight, .tLeft]
		if  let                    buttonID  = button.kickoffToolID,
			autorepeaters.contains(buttonID) {
			button.isContinuous              = true

			button.setPeriodicDelay(0.5, interval: 0.1)
		}
	}

	override func handleSignal(kind: ZSignalKind) {
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
		flags.hasShift   = buttonFor(.tShift)?  .state == NSControl.StateValue.on
		flags.hasOption  = buttonFor(.tOption)? .state == NSControl.StateValue.on
		flags.hasCommand = buttonFor(.tCommand)?.state == NSControl.StateValue.on
		flags.hasControl = buttonFor(.tControl)?.state == NSControl.StateValue.on
	}

}
