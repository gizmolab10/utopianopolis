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
	@IBOutlet var textView: ZTextView?
	var essay: ZParagraph? { return zone?.essay }
	var zone:  Zone?       { return gSelecting.firstGrab }

	func export() { gFiles.exportToFile(.eEssay, for: zone) }
	func save()   { essay?.saveEssay(textView?.textStorage) }

	func clear() {
		zone?.essayMaybe = nil

		if  let length = textView?.textStorage?.length, length > 0 {
			textView?.textStorage?.replaceCharacters(in: NSRange(location: 0, length: length), with: "")
		}
	}

	func setup() {
		clear() 									// discard previously edited text

		if  let 			 	    text = essay?.essayText {
			textView?  		   .delegate = nil	    // clear so that shouldChangeTextIn won't be called on insertText below
			textView?         .usesRuler = true
			textView?    .isRulerVisible = true
			textView?  .usesInspectorBar = true
			textView?.textContainerInset = NSSize(width: 20, height: 0)

			textView?.insertText(text, replacementRange: NSRange())

			textView?.delegate 	         = self 	// set delegate after insertText

			gWindow?.makeFirstResponder(textView)
		}
	}

	func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString text: String?) -> Bool {
		if  let length = text?.length,
			let result = essay?.updateEssay(range, length: length) {

			switch result {
				case .eAlter: 		return true
				case .eLock: 		return false
				case .eExit: 		gEssayEditor.swapGraphAndEssay()
				case .eDelete:
					FOREGROUND {			// defer until after this method returns
						self.setup()		// reset all text and restore cursor position
					}
			}

			return true
		}

		return text == nil
	}

}

