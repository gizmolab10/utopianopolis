//
//  ZEssayView.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 12/22/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation
import CloudKit

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
	@IBOutlet var textView : ZTextView?
	var backwardButton     : ZButton?
	var forwardButton      : ZButton?
	var essayID            : CKRecord.ID?
	var grabbedZone 	   : Zone? { return gCurrentEssay?.zone }
	var selectionRange 	   = NSRange() { didSet { selectionRect = textView?.firstRect(forCharacterRange: selectionRange, actualRange: nil) ?? CGRect() } }
	var selectionRect      = CGRect()

	func export() { gFiles.exportToFile(.eEssay, for: grabbedZone) }
	func save()   { gCurrentEssay?.saveEssay(textView?.textStorage) }
	func exit()   { save(); gControllers.swapGraphAndEssay() }

	// MARK:- setup
	// MARK:-

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		addControls()
		setup()
	}

	func clear() {
		grabbedZone?     .essayMaybe = nil
		textView?		   .delegate = nil	    			// clear so that shouldChangeTextIn won't be invoked on insertText or replaceCharacters
		textView?         .usesRuler = true
		textView?    .isRulerVisible = true
		textView?  .usesInspectorBar = true
		textView?.textContainerInset = NSSize(width: 20, height: 0)

		if  let length = textView?.textStorage?.length, length > 0 {
			textView?.textStorage?.replaceCharacters(in: NSRange(location: 0, length: length), with: "")
		}
	}

	func setup(restoreSelection: Int? = nil) {
		if  restoreSelection == nil,				// if called from viewWillAppear
			gCurrentEssay?.essayMaybe?.needsSave ?? false,
			essayID != nil,							// been here before
			essayID == grabbedZone?.record?.recordID {

			return									// has not yet been saved. don't overwrite
		}

		clear() 									// discard previously edited text

		if  let text = gCurrentEssay?.essayText {
			essayID  = grabbedZone?.record?.recordID

			gEsssyRing.push()
			textView?.setText(text)
			select(restoreSelection: restoreSelection)
			updateButtons(true)

			textView?.delegate = self 		// set delegate after insertText

			gWindow?.makeFirstResponder(textView)
		}
	}

	func select(restoreSelection: Int? = nil) {
		if  let e = gCurrentEssay, e.lastTextIsDefault,
			var range      = e.lastTextRange {			// select entire text of final essay
			if  let offset = restoreSelection {
				range      = NSRange(location: offset, length: 0)
			}

			textView?.setSelectedRange(range)
		} else {
			textView?.scroll(CGPoint())					// scroll to top
		}
	}

	func updateButtons(_ flag: Bool) {
		forwardButton? .isEnabled = flag
		backwardButton?.isEnabled = flag
	}

	// MARK:- events
	// MARK:-

	func handleCommandKey(_ iKey: String?, flags: ZEventFlags) -> Bool {   // false means key not handled
		guard let key = iKey else {
			return false
		}

		let OPTION = flags.isOption

		switch key {
			case "a":      textView?.selectAll(nil)
			case "e":      export()
			case "h":      showHyperlinkPopup()
			case "i":      showSpecialsPopup()
			case "l", "u": alterCase(up: key == "u")
			case "s":      save()
			case "]":      gEsssyRing.goBack()
			case "[":      gEsssyRing.goForward()
			case kReturn:  if OPTION { accountForSelection() }; exit()
			default:       return false
		}

		return true
	}

	func accountForSelection() {
		gSelecting.ungrabAll()

		for paragraph in selectedParagraphs {
			paragraph.zone?.addToGrab()
		}
	}

	func alterCase(up: Bool) {
		if  let        text = textView?.textStorage?.attributedSubstring(from: selectionRange).string {
			let replacement = up ? text.uppercased() : text.lowercased()

			textView?.insertText(replacement, replacementRange: selectionRange)
		}
	}

	enum ZTextButtonID : Int {
		case idBack
		case idForward

		var title: String {
			switch self {
				case .idForward: return "􀓅"
				case .idBack:    return "􀓄"
			}
		}
	}

	@objc func handleButtonPress(_ iButton: ZButton) {
		if let buttonID = ZTextButtonID(rawValue: iButton.tag) {
			switch buttonID {
				case .idForward: gEsssyRing.goForward()
				case .idBack:    gEsssyRing.goBack()
			}
		}
	}

	func addControls() {
		FOREGROUND {
			if  let w = gWindow,
				let inspectorBar = w.titlebarAccessoryViewControllers.first(where: { $0.view.className == "__NSInspectorBarView" } )?.view {

				func addButton(_ tag: ZTextButtonID) -> ZButton {
					let        index = inspectorBar.subviews.count - 1
					var        frame = inspectorBar.subviews[index].frame
					let            x = frame.maxX - ((tag == .idBack) ? 0.0 : 6.0)
					let        title = tag.title
					let       button = ZButton(title: title, target: self, action: #selector(self.handleButtonPress))
					frame      .size = button.bounds.insetBy(dx: 0.0, dy: 4.0).size
					frame    .origin = CGPoint(x: x, y: 0.0)
					button    .frame = frame
					button      .tag = tag.rawValue
					button.isEnabled = false

					inspectorBar.addSubview(button)

					return button
				}

				self.backwardButton = addButton(.idBack)
				self.forwardButton  = addButton(.idForward)
			}
		}
	}

	// MARK:- special characters
	// MARK:-

	func showSpecialsPopup() {
		NSMenu.specialsPopup(target: self, action: #selector(handleSpecialsPopupMenu(_:))).popUp(positioning: nil, at: selectionRect.origin, in: nil)
	}

	@objc func handleSpecialsPopupMenu(_ iItem: ZMenuItem) {
		if  let  type = ZSpecialsMenuType(rawValue: iItem.keyEquivalent),
			type     != .eCancel {
			let  text = type.text

			textView?.insertText(text, replacementRange: selectionRange)
		}
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
		let  	  item = NSMenuItem(title: type.title, action: #selector(handleHyperlinkPopupMenu(_:)), keyEquivalent: type.rawValue)
		item   .target = self
		item.isEnabled = true

		item.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: 0)

		return item
	}

	@objc func handleHyperlinkPopupMenu(_ iItem: ZMenuItem) {
		if  let type = ZHyperlinkMenuType(rawValue: iItem.keyEquivalent) {
			var link: String? = type.linkType + kSeparator

			switch type {
				case .eClear: link = nil // to remove existing hyperlink
				case .eWeb:   link?.append("//apple.com")
				default:      if let b = gSelecting.pastableRecordName { link?.append(b) } else { return }
			}

			if  link == nil {
				textView?.textStorage?.removeAttribute(.link,               range: selectionRange)
			} else {
				textView?.textStorage?   .addAttribute(.link, value: link!, range: selectionRange)
			}
		}
	}

	var selectedParagraphs: [ZParagraph] {
		var array = [ZParagraph]()

		if  let zones = grabbedZone?.paragraphs {
			for zone in zones {
				if  let paragraph = zone.essayMaybe, paragraph.paragraphRange.inclusiveIntersection(selectionRange) != nil {
					array.append(paragraph)
				}
			}
		}

		return array
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

		if  let f = found as? NSURL {
			found = f.absoluteString
		}

		return found
	}

	@discardableResult func followCurrentLink(within range: NSRange) -> Bool {
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
							let  common = grabbedZone?.closestCommonParent(of: grabbed) {
							gHere       = common

							FOREGROUND {
								gControllers.signalFor(nil, regarding: .eRelayout)

								if  let e = grabbed.essayMaybe, gCurrentEssay?.children.contains(e) ?? false {
									self.textView?.setSelectedRange(e.essayTextRange) 	// select text range of grabbed essay
								} else {
									gCreateMultipleEssay = true
									gCurrentEssay = grabbed.essay

									grabbed.asssureIsVisible()
									grabbed.grab()										// focus on zone with rID (before calling setup, which uses current grab)
									gCurrentEssay?.essayMaybe?.clearSave()
									self.setup()
								}
							}

							return true
						}
					case .eIdea:
						if  let grabbed = grab,
							let  common = grabbedZone?.closestCommonParent(of: grabbed) {
							gHere       = common

							grabbed       .grab()												// focus on zone with rID
							grabbed       .asssureIsVisible()
							grabbedZone?  .asssureIsVisible()
							gCurrentEssay?.essayMaybe?.clearSave()

							FOREGROUND {
								gControllers.swapGraphAndEssay()
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

	func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRange oldRange: NSRange, toCharacterRange newRange: NSRange) -> NSRange {
		selectionRange = newRange

		return newRange
	}

	func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
		return followCurrentLink(within: NSRange(location: charIndex, length: 0))
	}

	// MARK:- lockout editing of added whitespace
	// MARK:-

	func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString text: String?) -> Bool {
		if  let length = text?.length,
			let (result, delta) = gCurrentEssay?.updateEssay(range, length: length) {

			switch result {
				case .eAlter: return true
				case .eLock:  return false
				case .eExit:  gControllers.swapGraphAndEssay()
				case .eDelete:
					FOREGROUND {							// defer until after this method returns ... avoids corrupting newly setup text
						self.setup(restoreSelection: delta)	// reset all text and restore cursor position
					}
			}

			gCurrentEssay!.essayLength += delta

			return true
		}

		return text == nil
	}

}

