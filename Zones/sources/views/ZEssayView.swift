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

var gEssayView: ZEssayView? { return gEssayController?.essayView }

class ZEssayView: ZView, ZTextViewDelegate {
	@IBOutlet var editor: ZTextView?
	var _essay: ZEssay?

	var  essay: ZEssay {
		get {
			if  _essay == nil {
				_essay = ZEssay(gSelecting.firstGrab)
			}

			return _essay!
		}
	}

	func save() { essay.save(editor?.textStorage) }

	func clear() {
		_essay = nil

		if  let length = editor?.textStorage?.length, length > 0 {
			editor?.textStorage?.replaceCharacters(in: NSRange(location: 0, length: length), with: "")
		}
	}

	func begin() {
		clear() 								// discard previously edited text

		if  let 				  text = essay.essayText {
			editor?.textContainerInset = NSSize(width: 10, height: 10)
			editor?  		 .delegate = nil	// clear so that delegate calls won't happen on insertText below

			editor?.insertText(text, replacementRange: NSRange())

			editor?.delegate 	       = self 	// call after insertText so delegate calls won't happen

			gWindow?.makeFirstResponder(editor)
		}
	}

	func textView(_ textView: NSTextView, shouldChangeTextInRanges affectedRanges: [NSValue], replacementStrings: [String]?) -> Bool {
		var should = true

		if  let strings = replacementStrings {
			for (index, value) in affectedRanges.enumerated() {
				if  let range = value as? NSRange,
					!essay.update(range, length: strings[index].length) {

					if  range == essay.essayRange {
						essay.delete()
						gEssayEditor.swapGraphAndEssay()
					}

					should = false

					break
				}
			}
		}

		return should
	}

}

