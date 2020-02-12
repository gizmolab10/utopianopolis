//
//  ZEssayEditor.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 12/22/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

let gEssayEditor = ZEssayEditor()

class ZEssayEditor: ZBaseEditor {
	override func canHandleKey() -> Bool { return gIsNoteMode }

	override func isValid(_ key: String, _ flags: ZEventFlags, inWindow: Bool = true) -> Bool {
		if !gIsNoteMode || inWindow {
			return false
		}

		return true
	}

	@discardableResult override func handleKey(_ iKey: String?, flags: ZEventFlags, isWindow: Bool) -> Bool {   // false means key not handled
		if !super.handleKey(iKey, flags: flags, isWindow: isWindow),
			var     key = iKey {
			let  OPTION = flags.isOption
			let COMMAND = flags.isCommand

			if  key    != key.lowercased() {
				key     = key.lowercased()
			}

			if  let arrow = key.arrow {
				handleArrow(arrow, flags: flags)

				return true
			} else if  COMMAND {
				switch key {
					default:       return gEssayView?.handleKey(iKey, flags: flags) ?? false
				}
			} else {
				switch key {
					case kEscape:  if OPTION { gEssayView?.accountForSelection() }; gControllers.swapGraphAndEssay(); return true
					default:       return gEssayView?.handleKey(iKey, flags: flags) ?? false
				}
			}
		}
		
		return false
	}

	func handleArrow(_ arrow: ZArrowKey, flags: ZEventFlags) {
		if  let    view = gEssayView {
			let  OPTION = flags.isOption
			let COMMAND = flags.isCommand
			let SPECIAL = COMMAND && OPTION

			if         SPECIAL {
				switch arrow {
					case .left,
						 .right: view.move(out: arrow == .left)
					default:     break
				}
			} else if  COMMAND {
				switch arrow {
					case .up:    view.moveToBeginningOfParagraph(nil)
					case .down:  view.moveToEndOfParagraph(nil)
					case .left:  view.moveToBeginningOfLine(nil)
					case .right: view.moveToEndOfLine(nil)
				}
			} else if  OPTION {
				switch arrow {
					case .up:    view.moveToLeftEndOfLine(nil)
					case .down:  view.moveToRightEndOfLine(nil)
					case .left:  view.moveWordBackward(nil)
					case .right: view.moveWordForward(nil)
				}
			} else {
				switch arrow {
					case .up:    view.moveUp(nil)
					case .down:  view.moveDown(nil)
					case .left:  view.moveLeft(nil)
					case .right: view.moveRight(nil)
				}
			}
		}
	}

//	func updateFontSize(_ increment: Bool) {
//		if  let essayView = gEssayView,
//			let   current = gCurrentEssay, current.updateFontSize(increment) {
//			let    offset = essayView.selectionRange.location
//			gEssayTitleFontSize += CGFloat((increment ? 1.0 : -1.0) * 6.0)
//
//			essayView.updateText(restoreSelection: offset)
//		}
//	}

}

