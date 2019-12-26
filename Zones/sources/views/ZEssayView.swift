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

class ZEssayView: ZView {
	@IBOutlet var  label: ZTextField?
	@IBOutlet var editor: ZTextView?

	func clearEditor() {
		if  let length = editor?.textStorage?.length, length > 0 {
			editor?.textStorage?.replaceCharacters(in: NSRange(location: 0, length: length), with: "")
		}
	}

	func beginEditing() {
		clearEditor()

		gEssayView = self

		if  let        zone = gEssayEditor.zone {
			if  let    name = zone.zoneName {
				label?.text = "Essay for: \(name)"
			}

			if  let    text = zone.trait(for: .eEssay).essayText {
				editor?.insertText(text)
			}

			becomeFirstResponder()
		}
	}

	func endEditing() {
		if  let  zone = gEssayEditor.zone {
			let write = zone.trait(for: .eEssay)

			write.essayText = editor?.textStorage

			write.needSave()
			zone .needSave()
		}
	}
}

