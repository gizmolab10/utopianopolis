//
//  ZStartHereController.swift
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

var gSimpleToolsController: ZSimpleToolsController? { return gControllers.controllerForID(.idStartHere) as? ZSimpleToolsController }

class ZSimpleToolsController: ZGenericController, ZTooltips {

	override var controllerID : ZControllerID { return .idStartHere }
	var            isRelocate :   Bool { return flags.isOption  && !gIsEditing }
	var               isMixed :   Bool { return flags.isShift   && !gIsEditing && !flags.isOption }
	var            canUnfocus :   Bool { return flags.isControl && (gRecentsRoot?.children.count ?? 0) > 1 }
	var             canTravel :   Bool { return gIsMapMode && gGrabbedCanTravel }
	var            swapDBText : String { return "switch to \(gIsMine ? "everyone's" : "my") ideas" }
	var           expandMaybe : String { return isMixed ? "expand selection " : "" }
	var                 flags = ZEventFlags()
	var        buttonsByID    = [ZStartHereID  :  ZSimpleToolButton]()
	var          boxesByID    = [ZStartHereID  :  ZBox]()
	func       buttonFor(_ id :  ZStartHereID) -> ZSimpleToolButton? { return buttonsByID[id] }
	func          boxFor(_ id :  ZStartHereID) -> ZBox?             { return boxesByID  [id] }

	func updateBoxesAndButtons() {

		// provide useful hits about how behavior changes with work mode and modifier keys

		buttonFor(.control)?.isEnabled = !gIsSearchMode
		buttonFor(.option)? .isEnabled = !gIsSearchMode
		buttonFor(.shift)?  .isEnabled = !gIsSearchMode
		buttonFor(.focus)?  .isEnabled =  gIsMapMode
		buttonFor(.note)?   .isEnabled = !gIsEditIdeaMode
		boxFor   (.edit)?    .isHidden =  gIsSearchMode || gIsNoteMode
		boxFor   (.add)?     .isHidden =  gIsSearchMode || gIsNoteMode
		buttonFor(.swapDB)?     .title =  swapDBText
		buttonFor(.sibling)?    .title =  flags.isOption   ? "parent"       : "sibling"
		buttonFor(.up)?         .title =  expandMaybe      + "up"
		buttonFor(.down)?       .title =  expandMaybe      + "down"
		buttonFor(.left)?       .title =  isMixed          ? "conceal"      : "left"
		buttonFor(.right)?      .title =  isMixed          ? "reveal"       : canTravel ? "travel" : "right"
		buttonFor(.focus)?      .title =  canUnfocus       ? "unfocus"      : canTravel ? "travel" : gIsHere ? gCurrentSmallMapName : "focus"
		buttonFor(.tooltip)?    .title = (gShowToolTips    ? "dis"          : "en")     + "able tooltips"
		boxFor   (.move)?       .title = (isRelocate       ? "Relocate"     : isMixed   ? "Mixed"  : "Browse") + (flags.isCommand ? " to end"  : "")
		boxFor   (.edit)?       .title =  gIsEditing       ? "Stop Editing" : "Edit"
	}

	@IBAction func buttonAction(_ button: ZSimpleToolButton) {
		update()

		if  let itemID = button.startHereID,
			let    key = keyFrom(itemID) {

			gMainWindow?.handleKey(key, flags: flags)    // this is so cool, ;-)
		}
	}

	override func startup() {

		// //////////////////////////////////// //
		// map buttons & boxes, using their ids //
		// //////////////////////////////////// //

		view.applyToAllSubviews { subview in
			if  let         box       = subview as? ZBox,
				let         boxID     = box.startHereID {
				boxesByID  [boxID]    = box
			} else if let   button    = subview as? ZSimpleToolButton,
				let         buttonID  = button.startHereID {
				buttonsByID[buttonID] = button

				setAutoRepeat(for: button)
			}
		}
	}

	func setAutoRepeat(for button: ZSimpleToolButton) {
		let autorepeaters: [ZStartHereID] = [.up, .down, .right, .left]
		if  let                    buttonID  = button.startHereID,
			autorepeaters.contains(buttonID) {
			button.isContinuous              = true

			button.setPeriodicDelay(0.5, interval: 0.1)
		}
	}

	override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		if  let c = gDetailsController, !c.hideableIsHidden(for: .StartHere) { // ignore if hidden
			update()
		}
	}

	func update() {
		updateFlags() // must call this first as others rely on flags
		updateTooltips()
		updateBoxesAndButtons()
	}

	func updateFlags() {
		flags.isShift   = buttonFor(.shift)?  .state == NSControl.StateValue.on
		flags.isOption  = buttonFor(.option)? .state == NSControl.StateValue.on
		flags.isCommand = buttonFor(.command)?.state == NSControl.StateValue.on
		flags.isControl = buttonFor(.control)?.state == NSControl.StateValue.on
	}

	func arrowFrom(_ from: ZStartHereID) -> ZArrowKey? {
		switch from {
			case .up:      return .up
			case .down:    return .down
			case .left:    return .left
			case .right:   return .right
			default:       return  nil
		}
	}

	func keyFrom(_ from: ZStartHereID) -> String? {
		switch from {
			case .note:    return "n"
			case .focus:   return "/"
			case .tooltip: return "y"
			case .sibling: return kTab
			case .swapDB:  return kBackSlash
			case .child:   return kSpace
			case .idea:    return kReturn
			default:       return arrowFrom(from)?.key
		}
	}

}
