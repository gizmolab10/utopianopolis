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
	
	func setup() {
		editor?.delegate = self

		if  let zone = gEssayEditor.zone,
			let name = zone.zoneName {
			label?.text = "editing: \(name)"
			clearEditor()

			if  let base64 = zone.essay,
				let   data = Data(base64Encoded: base64),
				let   text = NSKeyedUnarchiver.unarchiveObject(with: data) as? NSMutableAttributedString {
				editor?.insertText(text)
			}
		}
	}
	
	func clearEditor() {
		let length = editor?.textStorage?.length ?? 0
		editor?.textStorage?.replaceCharacters(in: NSRange(location: 0, length: length), with: "")
	}
	
	func textView(_ textView: NSTextView, shouldChangeTextInRanges affectedRanges: [NSValue], replacementStrings: [String]?) -> Bool {
		if  let   zone = gEssayEditor.zone,
			let   text = editor?.textStorage {
			let   data = NSKeyedArchiver.archivedData(withRootObject: text)
			let  essay = data.base64EncodedString()
			zone.essay = essay
			
			zone.needSave()
		}
			
		return true
	}
}

