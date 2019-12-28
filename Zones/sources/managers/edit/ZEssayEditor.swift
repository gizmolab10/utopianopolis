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
	override var workMode: ZWorkMode { return .essayMode }

	override func isValid(_ key: String, _ flags: ZEventFlags, inWindow: Bool = true) -> Bool {
		if  gWorkMode != .essayMode || inWindow {
			return false
		}

		return true
	}

	@discardableResult override func handleKey(_ iKey: String?, flags: ZEventFlags, isWindow: Bool) -> Bool {   // false means key not handled
		if  var     key = iKey {
			let COMMAND = flags.isCommand
			let  OPTION = flags.isOption
			let SPECIAL = COMMAND && OPTION
			
			if  key    != key.lowercased() {
				key     = key.lowercased()
			}

			if  let arrow = key.arrow {
				handleArrow(arrow, flags: flags)
			}

			if  COMMAND {
				switch key {
					case "a": gEssayView?.editor?.selectAll(nil)
//					case "b": gEssayView?.editor?.bold(nil)
					case "s": gEssayView?.save()
					case "w": swapGraphAndEssay()
					case "/": if SPECIAL { showHideKeyboardShortcuts() }
					default:  break
				}
			}

			switch key {
				case kEscape: swapGraphAndEssay()
				default:  			   break
			}
		}
		
		return false
	}

	func handleArrow(_ arrow: ZArrowKey, flags: ZEventFlags) {
		if  let  editor = gEssayView?.editor {
			let COMMAND = flags.isCommand
			let  OPTION = flags.isOption

			if  COMMAND {
				switch arrow {
					case .up:    editor.moveToBeginningOfParagraph(nil)
					case .down:  editor.moveToEndOfParagraph(nil)
					case .left:  editor.moveToBeginningOfLine(nil)
					case .right: editor.moveToEndOfLine(nil)
				}
			} else if  OPTION {
				switch arrow {
					case .up:    editor.moveToLeftEndOfLine(nil)
					case .down:  editor.moveToRightEndOfLine(nil)
					case .left:  editor.moveWordBackward(nil)
					case .right: editor.moveWordForward(nil)
				}
			} else {
				switch arrow {
					case .up:    editor.moveUp(nil)
					case .down:  editor.moveDown(nil)
					case .left:  editor.moveLeft(nil)
					case .right: editor.moveRight(nil)
				}
			}
		}
	}
}
