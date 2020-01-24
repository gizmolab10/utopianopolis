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

var gEssayView: ZEssayView? { return gEssayController?.essayView }

class ZEssayView: ZView, ZTextViewDelegate {
	@IBOutlet var textView : ZTextView?
	var backwardButton     : ZButton?
	var forwardButton      : ZButton?
	var cancelButton       : ZButton?
	var doneButton         : ZButton?
	var saveButton         : ZButton?
	var essayID            : CKRecord.ID?
	var grabbedZone 	   : Zone?     { return gCurrentEssay?.zone }
	var selectionString    : String?   { return textView?.textStorage?.attributedSubstring(from: selectionRange).string }
	var selectionRange     = NSRange() { didSet { selectionRect = textView?.firstRect(forCharacterRange: selectionRange, actualRange: nil) ?? CGRect() } }
	var selectionRect      = CGRect()
	var selectionZone      : Zone?     { return selectedParagraphs.first?.zone }

	func save()   { gCurrentEssay?.saveEssay(textView?.textStorage); accountForSelection() }
	func export() { gFiles.exportToFile(.eEssay, for: grabbedZone) }
	func exit()   { gControllers.swapGraphAndEssay() }
	func done()   { save(); exit() }

	// MARK:- setup
	// MARK:-

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		addButtons()
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

	func reset(restoreSelection: Int? = nil) {
		gCurrentEssay?.reset()
		setup(restoreSelection: restoreSelection)
	}

	func setup(restoreSelection: Int? = nil) {
		if  restoreSelection == nil,				// if called from viewWillAppear
			gCurrentEssay?.essayMaybe?.needsSave ?? false,
			essayID != nil,							// been here before
			essayID == grabbedZone?.record?.recordID {

			return									// has not yet been saved. don't overwrite
		}

		if  let text = gCurrentEssay?.essayText {
			clear() 									// discard previously edited text
			gEssayRing.push()
			updateButtons(true)
			textView?.setText(text)
			select(restoreSelection: restoreSelection)

			essayID  		   = grabbedZone?.record?.recordID
			textView?.delegate = self 		// set delegate after setText

			gWindow?.makeFirstResponder(textView)
		}
	}

	func handleCommandKey(_ iKey: String?, flags: ZEventFlags) -> Bool {   // false means key not handled
		guard let key = iKey else {
			return false
		}

		let CONTROL = flags.isControl
		let  OPTION = flags.isOption

		switch key {
			case "a":      textView?.selectAll(nil)
			case "d":      convertToChild(createEssay: CONTROL && OPTION)
			case "e":      export()
			case "h":      showHyperlinkPopup()
			case "i":      showSpecialsPopup()
			case "l", "u": alterCase(up: key == "u")
			case "s":      save()
			case "/":      gEssayRing.pop()
			case "]":      gEssayRing.goBack()
			case "[":      gEssayRing.goForward()
			case kReturn:  grabbedZone?.grab(); done()
			default:       return false
		}

		return true
	}

	// MARK:- internals
	// MARK:-

	private func convertToChild(createEssay: Bool) {
		if  let   text = selectionString, text.length > 0,
			let parent = selectionZone {
			let  child = Zone(databaseID: grabbedZone?.databaseID, named: text, identifier: nil)    // create new zone from text

			textView?.insertText("", replacementRange: selectionRange)	// remove text
			parent.addChild(child, at: parent.insertionIndex) 			// add it as child to zone, respecting insertion mode
			child.asssureIsVisible()
			save()

			if  createEssay {
				child.setTraitText(kEssayDefault, for: .eEssay)			// create an essay in the new zone

				gCurrentEssay = grabbedZone?.essay

				reset()			    									// redraw essay TODO: WITH NEW PARAGRAPH SELECTED
			} else {
				exit()
				child.grab()

				FOREGROUND {
					child.edit()
				}
			}
		}
	}

	private func alterCase(up: Bool) {
		if  let        text = selectionString {
			let replacement = up ? text.uppercased() : text.lowercased()

			textView?.insertText(replacement, replacementRange: selectionRange)
		}
	}

	func move(out: Bool) {
		gCreateMultipleEssay = true
		let        selection = selectedParagraphs

		func setEssay(_ current: ZParagraph) {
			gCurrentEssay = current

			self.reset()
		}

		if !out, let last = selection.last {
			setEssay(last)
		} else if out {
			grabbedZone?.traverseAncestors { ancestor -> (ZTraverseStatus) in
				if  ancestor != grabbedZone, ancestor.hasEssay {
					setEssay(ancestor.essay)

					return .eStop
				}

				return .eContinue
			}
		}
	}

	private func select(restoreSelection: Int? = nil) {
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

	func accountForSelection() {
		var needsUngrab = true

		for paragraph in selectedParagraphs {
			if  let grab = paragraph.zone {
				if  needsUngrab {
					needsUngrab = false
					gSelecting.ungrabAll()
				}

				grab.asssureIsVisible()
				grab.addToGrab()
			}
		}
	}

	// MARK:- special characters
	// MARK:-

	private func showSpecialsPopup() {
		NSMenu.specialsPopup(target: self, action: #selector(handleSpecialsPopupMenu(_:))).popUp(positioning: nil, at: selectionRect.origin, in: nil)
	}

	@objc private func handleSpecialsPopupMenu(_ iItem: ZMenuItem) {
		if  let  type = ZSpecialsMenuType(rawValue: iItem.keyEquivalent),
			type     != .eCancel {
			let  text = type.text

			textView?.insertText(text, replacementRange: selectionRange)
		}
	}

	// MARK:- buttons
	// MARK:-

	enum ZTextButtonID : Int {
		case idForward
		case idCancel
		case idBack
		case idSave
		case idDone

		var title: String {
			switch self {
				case .idForward: return "􀓅"
				case .idCancel:  return "Cancel"
				case .idDone:    return "Done"
				case .idSave:    return "Save"
				case .idBack:    return "􀓄"
			}
		}

		static var all: [ZTextButtonID] { return [.idBack, .idForward, .idDone, .idSave, .idCancel] }
	}

	func updateButtons(_ flag: Bool) {
		doneButton?    .isEnabled = flag
		saveButton?    .isEnabled = flag
		cancelButton?  .isEnabled = flag
		forwardButton? .isEnabled = flag
		backwardButton?.isEnabled = flag
	}

	private func setButton(_ button: ZButton) {
		if let tag = ZTextButtonID(rawValue: button.tag) {
			switch tag {
				case .idForward: forwardButton = button
				case .idCancel:   cancelButton = button
				case .idBack:   backwardButton = button
				case .idDone:       doneButton = button
				case .idSave:       saveButton = button
			}
		}
	}

	@objc private func handleButtonPress(_ iButton: ZButton) {
		if let buttonID = ZTextButtonID(rawValue: iButton.tag) {
			switch buttonID {
				case .idForward: gEssayRing.goForward()
				case .idCancel:  grabbedZone?.grab(); exit()
				case .idDone:    grabbedZone?.grab(); done()
				case .idSave:    save()
				case .idBack:    gEssayRing.goBack()
			}
		}
	}

	private func addButtons() {
		FOREGROUND {		// wait for application to fully load the inspector bar
			if  let w = gWindow,
				let inspectorBar = w.titlebarAccessoryViewControllers.first(where: { $0.view.className == "__NSInspectorBarView" } )?.view {

				func button(for tag: ZTextButtonID) -> ZButton {
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

					return button
				}

				for tag in ZTextButtonID.all {
					let b = button(for: tag)

					inspectorBar.addSubview(b)
					self.setButton(b)
				}
			}
		}
	}

	// MARK:- hyperlinks
	// MARK:-

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

	private func showHyperlinkPopup() {
		let menu = NSMenu(title: "create a hyperlink")
		menu.autoenablesItems = false

		for type in ZHyperlinkMenuType.all {
			menu.addItem(item(type: type))
		}

		menu.popUp(positioning: nil, at: selectionRect.origin, in: nil)
	}

	private func item(type: ZHyperlinkMenuType) -> NSMenuItem {
		let  	  item = NSMenuItem(title: type.title, action: #selector(handleHyperlinkPopupMenu(_:)), keyEquivalent: type.rawValue)
		item   .target = self
		item.isEnabled = true

		item.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: 0)

		return item
	}

	@objc private func handleHyperlinkPopupMenu(_ iItem: ZMenuItem) {
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

		if  let e = grabbedZone?.essay,
			array.count == 0 {
			array.append(e)
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

	@discardableResult private func followCurrentLink(within range: NSRange) -> Bool {
		selectionRange = range

		if  let  link = currentLink as? String {
			let parts = link.components(separatedBy: kSeparator)

			if  parts.count > 1,
				let    t = parts.first?.first, // first character of first part
				let  rID = parts.last,
				let type = ZHyperlinkMenuType(rawValue: String(t)) {
				let zone = gSelecting.zone(with: rID)	// find zone with rID
				switch type {
					case .eEssay:
						if  let   grab = zone {
							let common = grabbedZone?.closestCommonParent(of: grab)

							if  let c  = common {
								gHere  = c
							}

							FOREGROUND {
								gControllers.signalFor(nil, regarding: .eRelayout)

								if  let e = grab.essayMaybe, gCurrentEssay?.children.contains(e) ?? false {
									self.textView?.setSelectedRange(e.essayTextRange) 	// select text range of grabbed essay
								} else {
									gCreateMultipleEssay = true
									gCurrentEssay        = grab.essay

									grab.asssureIsVisible()
									grab.grab()									// focus on zone with rID (before calling setup, which uses current grab)
									self.reset()
								}
							}

							return true
						}
					case .eIdea:
						if  let   grab = zone {
							let common = grabbedZone?.closestCommonParent(of: grab)

							if  let  c = common {
								gHere  = c
							}

							grab        .grab()												// focus on zone with rID
							grab        .asssureIsVisible()
							grabbedZone?.asssureIsVisible()

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
			let (result, delta) = gCurrentEssay?.shouldAlterEssay(range, length: length) {

			switch result {
				case .eAlter: return true
				case .eLock:  return false
				case .eExit:  gControllers.swapGraphAndEssay()
				case .eDelete:
					FOREGROUND {							// defer until after this method returns ... avoids corrupting reset text
						self.reset(restoreSelection: delta)	// reset all text and restore cursor position
				}
			}

			gCurrentEssay!.essayLength += delta

			return true
		}

		return text == nil // does this return value matter?
	}

}

