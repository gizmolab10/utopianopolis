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

class ZEssayView: ZView, ZTextViewDelegate {
	@IBOutlet var editor: ZTextView?
	var titleRange = NSRange()
	var  textRange = NSRange()

	func clear() {
		if  let length = editor?.textStorage?.length, length > 0 {
			editor?.textStorage?.replaceCharacters(in: NSRange(location: 0, length: length), with: "")
		}
	}

	func begin() {
		clear() // discard previously edited text

		gEssayView         = self
		editor?  .delegate = nil

		if  let       zone = gEssayEditor.zone {
			if  let   name = zone.zoneName {
				let  title = name + "\n\n"
				titleRange = NSRange(location: 0, length: title.length)
				let string = NSMutableAttributedString(string: title)

				string.addAttribute(.font, value: ZFont.systemFont(ofSize: 48.0), range: titleRange)
				editor?.insertText(string)
			}

			if  let   text = zone.trait(for: .eEssay).essayText {
				textRange  = NSRange(location: titleRange.upperBound, length: text.length)
				editor?.insertText(text)
			}

			editor?.delegate = self
			becomeFirstResponder()
		}
	}

	func save() {
		if  let        zone = gEssayEditor.zone,
			let  attributed = editor?.textStorage {
			let      string = attributed.string
			let        text = attributed.attributedSubstring(from: textRange)
			let       title = string.substring(with: titleRange).replacingOccurrences(of: "\n", with: "")
			let       essay = zone.trait(for: .eEssay)
			essay.essayText = text.mutableCopy() as? NSMutableAttributedString
			zone  .zoneName = title

			zone .needSave()
			essay.needSave()

			gControllers.signalFor(zone, multiple: [.eDatum])
		}
	}

	func update(_ range:NSRange, _ length: Int) {
		if  let       intersection = range.specialIntersection(textRange) {
			textRange     .length += length - intersection.length
		} else if let intersection = range.specialIntersection(titleRange) {
			let delta              = length - intersection.length
			titleRange    .length += delta
			textRange   .location += delta
		}
	}

	func textView(_ textView: NSTextView, shouldChangeTextInRanges affectedRanges: [NSValue], replacementStrings: [String]?) -> Bool {
		if  let strings = replacementStrings {
			for (index, value) in affectedRanges.enumerated() {
				if  let range = value as? NSRange {
					update(range, strings[index].length)
				}
			}
		}

		return true
	}

}

