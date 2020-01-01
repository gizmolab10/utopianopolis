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
	@IBOutlet var editorView: ZTextView?
	var essay: ZEssayPart? { return zone?.essay }
	var zone:  Zone?       { return gSelecting.firstGrab }

	func export() { gFiles.exportToFile(.eEssay, for: zone) }
	func save()   { essay?.save(editorView?.textStorage) }

	func clear() {
		zone?.essayMaybe = nil

		if  let length = editorView?.textStorage?.length, length > 0 {
			editorView?.textStorage?.replaceCharacters(in: NSRange(location: 0, length: length), with: "")
		}
	}

	func begin() {
		clear() 									// discard previously edited text

		if  let 					  text = essay?.essayText {
			editorView?.textContainerInset = NSSize(width: 10, height: 10)
			editorView?  		 .delegate = nil	// clear so that delegate calls won't happen on insertText below

			editorView?.insertText(text, replacementRange: NSRange())

			editorView?.delegate 	       = self 	// call after insertText so delegate calls won't happen

			gWindow?.makeFirstResponder(editorView)
		}
	}

	func textView(_ textView: NSTextView, shouldChangeTextInRanges affectedRanges: [NSValue], replacementStrings: [String]?) -> Bool {
		var         should     = false

		if  let     strings    = replacementStrings,
			let     e  		   = essay {
			for (index, value) in affectedRanges.enumerated() {
				if  let range  = value as? NSRange,
					e.updateEssay(range, length: strings[index].length) == .eAlter {
					should     = true
				} else {
					break
				}
			}
		}

		return should
	}

}

