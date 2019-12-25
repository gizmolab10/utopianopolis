//
//  ZEssayView.swift
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


var gEssayView: ZEssayView?

class ZEssayView: ZView { //, ZTextViewDelegate {
	@IBOutlet var label: ZTextField?
	@IBOutlet var editor: ZTextView?

	func clearEditor() {
		if  let length = editor?.textStorage?.length, length > 0 {
			editor?.textStorage?.replaceCharacters(in: NSRange(location: 0, length: length), with: "")
		}
	}

	func beginEditing() {
		clearEditor()

		gEssayView = self

		if  let zone = gEssayEditor.zone {
			if  let name = zone.zoneName {
				label?.text = "editing: \(name)"
			}

			if  let text = zone.essayText {
				editor?.insertText(text)
				becomeFirstResponder()
			}
		}
	}

	func endEditing() {
		if  let       zone = gEssayEditor.zone {
			zone.essayText = editor?.textStorage

			zone.needSave()
		}
	}
}

