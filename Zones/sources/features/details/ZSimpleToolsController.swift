//
//  ZSimpleToolsController.swift
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
	var           expandMaybe : String { return isMixed ? "expand selection " : kEmpty }
	var                 flags = ZEventFlags()
	var        buttonsByID    = [ZSimpleToolID  :  ZSimpleToolButton]()
	var          boxesByID    = [ZSimpleToolID  :  ZBox]()
	func       buttonFor(_ id :  ZSimpleToolID) -> ZSimpleToolButton? { return buttonsByID[id] }
	func          boxFor(_ id :  ZSimpleToolID) -> ZBox?              { return boxesByID  [id] }

	func updateBoxesAndButtons() {

		// provide useful hits about how behavior changes with work mode and modifier keys

		buttonFor(.control)?.isEnabled = !gIsSearchMode
		buttonFor(.option)? .isEnabled = !gIsSearchMode
		buttonFor(.shift)?  .isEnabled = !gIsSearchMode
		buttonFor(.focus)?  .isEnabled =  gIsMapMode
		buttonFor(.note)?   .isEnabled = !gIsEditIdeaMode
		boxFor   (.edit)?    .isHidden =  gIsSearchMode || gIsEssayMode
		boxFor   (.add)?     .isHidden =  gIsSearchMode || gIsEssayMode
		buttonFor(.swapDB)?     .title =  swapDBText
		buttonFor(.sibling)?    .title =  flags.isOption   ? "parent"       : "sibling"
		buttonFor(.up)?         .title =  expandMaybe      + "up"
		buttonFor(.down)?       .title =  expandMaybe      + "down"
		buttonFor(.left)?       .title =  isMixed          ? "conceal"      : "left"
		buttonFor(.right)?      .title =  isMixed          ? "reveal"       : canTravel ? "travel" : "right"
		buttonFor(.focus)?      .title =  canUnfocus       ? "unfocus"      : canTravel ? "travel" : gIsHere ? gCurrentSmallMapName : "focus"
		buttonFor(.tooltip)?    .title = (gShowToolTips    ? "dis"          : "en")     + "able tooltips"
		boxFor   (.move)?       .title = (isRelocate       ? "Relocate"     : isMixed   ? "Mixed"  : "Browse") + (flags.isCommand ? " to end"  : kEmpty)
		boxFor   (.edit)?       .title =  gIsEditing       ? "Stop Editing" : "Edit"
	}

	@IBAction func buttonAction(_ button: ZSimpleToolButton) {
		update()

		if  let itemID = button.simpleToolID,
			let    key = keyFrom(itemID) {
			var      f = flags

			if  key == "y" {
				f.isCommand = true // tweak needed because plain y otherwise cannot be typed into essays
			}

			gMainWindow?.handleKey(key, flags: f)    // this is so cool, ;-)
		}
	}

	override func startup() {

		// //////////////////////////////////// //
		// map buttons & boxes, using their ids //
		// //////////////////////////////////// //

		view.applyToAllSubviews { subview in
			if  let         box       = subview as? ZBox,
				let         boxID     = box.simpleToolID {
				boxesByID  [boxID]    = box
			} else if let   button    = subview as? ZSimpleToolButton,
				let         buttonID  = button.simpleToolID {
				buttonsByID[buttonID] = button

				setAutoRepeat(for: button)
			}
		}
	}

	func setAutoRepeat(for button: ZSimpleToolButton) {
		let autorepeaters: [ZSimpleToolID] = [.up, .down, .right, .left]
		if  let                    buttonID  = button.simpleToolID,
			autorepeaters.contains(buttonID) {
			button.isContinuous              = true

			button.setPeriodicDelay(0.5, interval: 0.1)
		}
	}

	override func handleSignal(_ object: Any?, kind: ZSignalKind) {
		if  gDetailsViewIsVisible(for: .vSimpleTools) { // ignore if hidden
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

	func arrowFrom(_ from: ZSimpleToolID) -> ZArrowKey? {
		switch from {
			case .up:      return .up
			case .down:    return .down
			case .left:    return .left
			case .right:   return .right
			default:       return  nil
		}
	}

	func keyFrom(_ from: ZSimpleToolID) -> String? {
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
