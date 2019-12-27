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
		clear() 	// discard previously edited text

		gEssayView      		   = self
		editor?  		 .delegate = nil
		editor?.textContainerInset = NSSize(width: 10, height: 10)

		if  let       zone = gEssayEditor.zone {
			if  let   name = zone.zoneName,
				let  color = zone.color,
				let   font = ZFont(name: "Times-Roman", size: 36.0),
				let   text = zone.trait(for: .eEssay).essayText {
				let  title = NSMutableAttributedString(string: name)
				let  blank = NSMutableAttributedString(string: "\n\n")
				titleRange = NSRange(location: 0, length: name.length)
				textRange  = NSRange(location: name.length + 2, length: text.length)

				let atributes: [NSAttributedString.Key:Any] = [.font:font, .foregroundColor:color]

				editor?.insertText(text,  replacementRange: NSRange()) 	// insert text first
				editor?.insertText(blank, replacementRange: NSRange())
				editor?.insertText(title, replacementRange: NSRange()) 	// insert title last
				editor?.textStorage?.addAttributes(atributes, range: titleRange)
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
		if  let       intersection = range.specialIntersection(textRange, includeUpper: true) {
			textRange     .length += length - intersection.length
		}

		if  let       intersection = range.specialIntersection(titleRange) {
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

