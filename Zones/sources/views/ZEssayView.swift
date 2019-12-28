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
	var _topic: ZTopic?

	var topic: ZTopic {
		get {
			if  _topic == nil {
				_topic = ZTopic(gSelecting.firstGrab)
			}

			return _topic!
		}
	}

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

		topic.begin(editor)
		becomeFirstResponder()

		editor?.delegate = self // call after begin editor so delegate calls won't happen on initial inserts
	}

	func save() {
		topic.save(editor?.textStorage)
	}

	func textView(_ textView: NSTextView, shouldChangeTextInRanges affectedRanges: [NSValue], replacementStrings: [String]?) -> Bool {
		var should = true

		if  let strings = replacementStrings {
			for (index, value) in affectedRanges.enumerated() {
				if  let range = value as? NSRange,
					!topic.update(range, strings[index].length) {
					should = false

					break
				}
			}
		}

		return should
	}

}

