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

enum ZHyperlinkMenuType: String {
	case eWeb   = "h"
	case eZone  = "t"
	case eImage = "i"

	var title: String {
		switch self {
			case .eWeb:   return "Internet"
			case .eZone:  return "Idea"
			case .eImage: return "Image"
		}
	}

	var both: (String, String) { return (rawValue, title) }
	static var all: [ZHyperlinkMenuType] { return [.eWeb, .eZone, .eImage] }

}
var gEssayView: ZEssayView? { return gEssayController?.essayView }

class ZEssayView: ZView, ZTextViewDelegate {
	@IBOutlet var textView: ZTextView?
	var essay: ZParagraph? { return zone?.essay }
	var zone:  Zone?       { return gSelecting.firstGrab }
	var selectionRect = CGRect()

	func export() { gFiles.exportToFile(.eEssay, for: zone) }
	func save()   { essay?.saveEssay(textView?.textStorage) }

	func clear() {
		zone?.essayMaybe = nil

		if  let length = textView?.textStorage?.length, length > 0 {
			textView?.textStorage?.replaceCharacters(in: NSRange(location: 0, length: length), with: "")
		}
	}

	func setup(applySelection: Int? = nil) {
		clear() 									// discard previously edited text

		if  let 					text = essay?.essayText {
			textView?		   .delegate = nil	    // clear so that shouldChangeTextIn won't be called on insertText below
			textView?         .usesRuler = true
			textView?    .isRulerVisible = true
			textView?  .usesInspectorBar = true
			textView?.textContainerInset = NSSize(width: 20, height: 0)

			textView?.insertText(text, replacementRange: NSRange())

			textView?.delegate 	         = self 	// set delegate after insertText

			if  var range      = essay?.lastTextRange {
				if  let offset = applySelection {
					range      = NSRange(location: offset, length: 0)
				}

				textView?.setSelectedRange(range)
			}

			gWindow?.makeFirstResponder(textView)
		}
	}

	func showHyperlinkPopup() {
		let menu = NSMenu(title: "create a hyperlink")
		menu.autoenablesItems = false

		for type in ZHyperlinkMenuType.all {
			menu.addItem(item(type: type))
		}

		menu.popUp(positioning: nil, at: selectionRect.origin, in: nil)
	}

	func item(type: ZHyperlinkMenuType) -> NSMenuItem {
		let  	  item = NSMenuItem(title: type.title, action: #selector(handlePopupMenu(_:)), keyEquivalent: type.rawValue)
		item.isEnabled = true
		item.target    = self

		item.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: 0)

		return item
	}

	@objc func handlePopupMenu(_ iItem: ZMenuItem) {
		if  let  type = ZHyperlinkMenuType(rawValue: iItem.keyEquivalent) {
			let  text = type.rawValue

			print(text + " \(selectionRect)")
		}
	}

	func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRange oldSelectedCharRange: NSRange, toCharacterRange newSelectedCharRange: NSRange) -> NSRange {
		selectionRect = textView.firstRect(forCharacterRange: newSelectedCharRange, actualRange: nil)

		return newSelectedCharRange
	}

	func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString text: String?) -> Bool {
		if  let length = text?.length,
			let (result, delta) = essay?.updateEssay(range, length: length) {

			switch result {
				case .eAlter: 		return true
				case .eLock: 		return false
				case .eExit: 		gEssayEditor.swapGraphAndEssay()
				case .eDelete:
					FOREGROUND {							// defer until after this method returns
						self.setup(applySelection: delta)	// reset all text and restore cursor position
					}
			}

			essay!.essayLength += delta

			return true
		}

		return text == nil
	}

}

