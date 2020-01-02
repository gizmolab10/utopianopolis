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
	func save()   { essay?.saveEssay(editorView?.textStorage) }

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
			editorView?.usesRuler          = true
			editorView?.isRulerVisible     = true
			editorView?.usesInspectorBar   = true

			gWindow?.makeFirstResponder(editorView)
			editorView?.selectLine(nil)
		}
	}

	func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString text: String?) -> Bool {
		if  let string = text,
			let  alter = essay?.updateEssay(range, length: string.length),
			alter     == .eAlter {
			return true
		}

		return text == nil
	}

}

