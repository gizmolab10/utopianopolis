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


class ZEssayView: ZView, ZTextViewDelegate {
	@IBOutlet var label: ZTextField?
	@IBOutlet var editor: ZTextView?
	
	override func awakeFromNib() {
		editor?.delegate = self
	}
	
	func setup() {
		clearEditor()

		if  let zone = gEssayEditor.zone {
			if  let name = zone.zoneName {
				label?.text = "editing: \(name)"
			}
			
			if  let text = zone.essayText {
				editor?.insertText(text)
			}
		}
	}
	
	func clearEditor() {
		if  let length = editor?.textStorage?.length, length > 0 {
			editor?.textStorage?.replaceCharacters(in: NSRange(location: 0, length: length), with: "")
		}
	}
	
	func textView(_ textView: NSTextView, shouldChangeTextInRanges affectedRanges: [NSValue], replacementStrings: [String]?) -> Bool {
		if  let       zone = gEssayEditor.zone {
			zone.essayText = editor?.textStorage
			
			zone.needSave()
		}
			
		return true
	}
}

