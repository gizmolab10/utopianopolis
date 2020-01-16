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
	case eIdea  = "i"
	case eEssay = "e"
	case eClear = "c"

	var title: String {
		switch self {
			case .eWeb:   return "Internet"
			case .eIdea:  return "Idea"
			case .eEssay: return "Essay"
			case .eClear: return "Clear"
		}
	}

	var linkType: String {
		switch self {
			case .eWeb: return "http"
			default:    return title.lowercased()
		}
	}

	static var all: [ZHyperlinkMenuType] { return [.eWeb, .eIdea, .eEssay, .eClear] }

}
var gEssayView: ZEssayView? { return gEssayController?.essayView }

class ZEssayView: ZView, ZTextViewDelegate {
	@IBOutlet var textView: ZTextView?
	var essay: ZParagraph? { return zone?.essay }
	var zone:  Zone?       { return gSelecting.firstGrab }
	var selectionRange = NSRange()
	var selectionRect  = CGRect()

	func export() { gFiles.exportToFile(.eEssay, for: zone) }
	func save()   { essay?.saveEssay(textView?.textStorage) }

	// MARK:- setup
	// MARK:-

	func clear() {
		zone?.essayMaybe = nil

		if  let length = textView?.textStorage?.length, length > 0 {
			textView?.textStorage?.replaceCharacters(in: NSRange(location: 0, length: length), with: "")
		}
	}

	func setup(restoreSelection: Int? = nil) {
		let exitSetup = (essay?.essayMaybe?.needsSave ?? false) && restoreSelection == nil

		if  exitSetup { return }								// has not yet been saved. don't overwrite

		clear() 												// discard previously edited text

		if  let 					text = essay?.essayText {
			textView?		   .delegate = nil	    			// clear so that shouldChangeTextIn won't be called on insertText below
			textView?         .usesRuler = true
			textView?    .isRulerVisible = true
			textView?  .usesInspectorBar = true
			textView?.textContainerInset = NSSize(width: 20, height: 0)

			textView?.setText(text)

			textView?.delegate 	         = self 				// set delegate after insertText

			if  var range      = essay?.lastTextRange {			// select entire text of final essay
				if  let offset = restoreSelection {
					range      = NSRange(location: offset, length: 0)
				}

				textView?.setSelectedRange(range)
			}

			gWindow?.makeFirstResponder(textView)
		}
	}

	func handleKey(_ iKey: String?) -> Bool {   // false means key not handled
		guard let key = iKey else {
			return false
		}

		switch key {
			case "a":     textView?.selectAll(nil)
			case "e":     export()
			case "h":     showHyperlinkPopup()
			case "s":     save()
			case kReturn: save(); gEssayEditor.swapGraphAndEssay()
			default:      return false
		}

		return true
	}

	// MARK:- hyperlinks
	// MARK:-

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
		item   .target = self
		item.isEnabled = true

		item.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: 0)

		return item
	}

	var pasteBuffer: String? {
		let pastables = gSelecting.pasteableZones

		if  pastables.count > 0 {
			let (pastable, (_, _)) = pastables.first!

			return pastable.recordName
		}

		return nil
	}


	@objc func handlePopupMenu(_ iItem: ZMenuItem) {
		if  let type = ZHyperlinkMenuType(rawValue: iItem.keyEquivalent) {
			var link: String? = type.linkType + kSeparator

			switch type {
				case .eClear: link = nil
				case .eWeb:   link?.append("//apple.com")
				default:      if let b = pasteBuffer { link?.append(b) } else { return }
			}

			if  link == nil {
				textView?.textStorage?.removeAttribute(.link,               range: selectionRange)
			} else {
				textView?.textStorage?   .addAttribute(.link, value: link!, range: selectionRange)
			}

			zone?.essay.essayMaybe?.needSave()
		}
	}

	var currentLink: Any? {
		var found: Any?
		var range = selectionRange

		if  let       length = textView?.textStorage?.length,
		    range.upperBound < length,
			range.length    == 0 {
			range.length     = 1
		}

		textView?.textStorage?.enumerateAttribute(.link, in: range, options: .reverse) { (item, inRange, flag) in
			found = item
		}

		return found
	}

	@discardableResult func followCurrentLink(within range: NSRange) -> Bool {
		selectionRect  = textView?.firstRect(forCharacterRange: range, actualRange: nil) ?? CGRect()
		selectionRange = range

		if  let   link = currentLink as? String {
			let  parts = link.components(separatedBy: kSeparator)

			if   parts.count > 1,
				let    t = parts.first?.first,
				let  rID = parts.last,
				let type = ZHyperlinkMenuType(rawValue: String(t)) {
				let grab = gSelecting.zone(with: rID)	// find zone with rID
				switch type {
					case .eEssay:
						if  let grabbed = grab,
							let  common = zone?.closestCommonParent(of: grabbed) {
							gHere       = common

							grabbed.grab()										// focus on zone with rID
							essay? .essayMaybe?.clearSave()

							FOREGROUND {
								self.setup()
								gControllers.signalFor(nil, regarding: .eRelayout)
							}

							return true
						}
					case .eIdea:
						if  let grabbed = grab,
							let  common = zone?.closestCommonParent(of: grabbed) {
							gHere       = common

							grabbed.grab()										// focus on zone with rID
							grabbed.asssureIsVisible()
							zone?  .asssureIsVisible()
							essay? .essayMaybe?.clearSave()

							FOREGROUND {
								gEssayEditor.swapGraphAndEssay()
								gControllers.signalFor(nil, regarding: .eRelayout)
							}

							return true
						}
					default: break
				}
			}
		}

		return false
	}

	func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRange oldSelectedCharRange: NSRange, toCharacterRange newSelectedCharRange: NSRange) -> NSRange {
		followCurrentLink(within: newSelectedCharRange)

		return newSelectedCharRange
	}

	func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
		return followCurrentLink(within: NSRange(location: charIndex, length: 0))
	}

	// MARK:- lockout editing of "extra" characters
	// MARK:-

	func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString text: String?) -> Bool {
		if  let length = text?.length,
			let (result, delta) = essay?.updateEssay(range, length: length) {

			switch result {
				case .eAlter: return true
				case .eLock:  return false
				case .eExit:  gEssayEditor.swapGraphAndEssay()
				case .eDelete:
					FOREGROUND {							// defer until after this method returns ... avoids corrupting newly setup text
						self.setup(restoreSelection: delta)	// reset all text and restore cursor position
					}
			}

			essay!.essayLength += delta

			return true
		}

		return text == nil
	}

}

