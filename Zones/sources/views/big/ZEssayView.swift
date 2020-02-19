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

class ZEssayView: ZTextView, ZTextViewDelegate {
	var backwardButton  : ZButton?
	var forwardButton   : ZButton?
	var cancelButton    : ZButton?
	var deleteButton    : ZButton?
	var hideButton      : ZButton?
	var saveButton      : ZButton?
	var selectionString : String?   { return textStorage?.attributedSubstring(from: selectionRange).string }
	var selectionRange  = NSRange() { didSet { selectionRect = rectForRange(selectionRange) } }
	var selectionZone   : Zone?     { return selectedNotes.first?.zone }
	var selectionRect   = CGRect()

	func done() { save(); exit() }

	func exit() {
		if  let e = gCurrentEssay,
			e.lastTextIsDefault,
			e.autoDelete {
			e.delete()
		}

		gControllers.swapGraphAndEssay()
	}

	func save() {
		if  let e = gCurrentEssay {
			e.saveEssay(textStorage)
			accountForSelection()
		}
	}

	// MARK:- setup
	// MARK:-

	override func awakeFromNib() {
		super.awakeFromNib()

		usesRuler              = true
		isRulerVisible         = true
		usesInspectorBar       = true
		textContainerInset     = NSSize(width: 20, height: 0)
		zlayer.backgroundColor = kClearColor.cgColor
		backgroundColor        = kClearColor

		addButtons()
		updateText()
	}

	private func clear() {
		gNoteAndEssay.grabbedZone?.noteMaybe = nil
		delegate = nil		// clear so that shouldChangeTextIn won't be invoked on insertText or replaceCharacters

		if  let length = textStorage?.length, length > 0 {
			textStorage?.replaceCharacters(in: NSRange(location: 0, length: length), with: "")
		}
	}

	func resetCurrentEssay(_ current: ZNote?, selecting zone: Zone? = nil) {
		if  let      note = current {
			gCurrentEssay = note

			gCurrentEssay?.reset()
			updateText()
			gCurrentEssay?.updateOffsets()
			gEssayRing.push()

			if  let range = zone?.noteMaybe?.offsetTextRange {
				setSelectedRange(range)
			}
		}
	}

	func updateText(restoreSelection: Int?  = nil) {
		if  (gNoteAndEssay.shouldOverwrite || restoreSelection != nil),
			let text = gCurrentEssay?.essayText {
			clear() 								// discard previously edited text
			gEssayRing.push()
			updateButtons(true)
			setText(text)							// emplace text
			select(restoreSelection: restoreSelection)

			gNoteAndEssay.essayID  = gNoteAndEssay.grabbedZone?.record?.recordID
			delegate = self 						// set delegate after setText

			gWindow?.makeFirstResponder(self)
		}
	}

	override func mouseDown(with event: ZEvent) {
		let    rect = CGRect(origin: event.locationInWindow, size: CGSize())
		let COMMAND = event.modifierFlags.isCommand
		let  inRing = gRingView?.respondToClick(in: rect, COMMAND) ?? false

		if !inRing {
			super.mouseDown(with: event)
		}
	}

	func handleKey(_ iKey: String?, flags: ZEventFlags) -> Bool {   // false means key not handled
		guard let key = iKey else {
			return false
		}

		let COMMAND = flags.isCommand
		let CONTROL = flags.isControl
		let  OPTION = flags.isOption
		let SPECIAL = COMMAND && OPTION
		let     ALL = SPECIAL && CONTROL

		if  COMMAND {
			switch key {
				case "a":      selectAll(nil)
				case "d":      convertToChild(createEssay: ALL)
				case "e":      gNoteAndEssay.export()
				case "h":      showHyperlinkPopup()
				case "i":      showSpecialsPopup()
				case "j":      gControllers.showHideRing()
				case "l", "u": alterCase(up: key == "u")
				case "n":      swapBetweenNoteAndEssay()
				case "s":      save()
				case "y":      if SPECIAL { gControllers.showHideTooltips() } else { gBreadcrumbs.toggleBreadcrumbExtent() }
				case "]":      gEssayRing.goForward()
				case "[":      gEssayRing.goBack()
				case kReturn:  gNoteAndEssay.grabbedZone?.grab(); done()
				default:       return false
			}

			return true
		} else if CONTROL {
			switch key {
				case "d":      convertToChild(createEssay: true)
				case "/":      popAndUpdate()
				default:       return false
			}

			return true
		}

		return false
	}

	// MARK:- private
	// MARK:-

	func swapBetweenNoteAndEssay() {
		if  let          current = gCurrentEssay,
			let             zone = current.zone {
			gCreateCombinedEssay = current.isNote
			let            count = zone.countOfNotes

			if  gCreateCombinedEssay {
				if  count > 1 {
					resetCurrentEssay(zone.freshEssay)
				}
			} else if count > 0,
				let note = zone.currentNote {
				resetCurrentEssay(note)
			}
		}
	}

	func popAndUpdate() {
		if  gEssayRing.popAndRemoveEmpties() {
			exit()
		} else {
			updateText()
		}
	}

	private func convertToChild(createEssay: Bool = false) {
		if  let   text = selectionString, text.length > 0,
			let   dbID = gNoteAndEssay.grabbedZone?.databaseID,
			let parent = selectionZone {
			let  child = Zone(databaseID: dbID, named: text)    		// create new (to be child) zone from text

			insertText("", replacementRange: selectionRange)			// remove text
			parent.addChild(child)
			child.asssureIsVisible()
			save()

			if  createEssay {
				child.setTextTrait(kEssayDefault, for: .eNote)			// create a placeholder essay in the child
				gNoteAndEssay.grabbedZone?.createNote()

				resetCurrentEssay(gNoteAndEssay.grabbedZone?.note, selecting: child)	// redraw essay TODO: WITH NEW NOTE SELECTED
			} else {
				exit()
				child.grab()

				FOREGROUND {											// defer idea edit until after this function exits
					child.edit()
				}
			}
		}
	}

	private func alterCase(up: Bool) {
		if  let        text = selectionString {
			let replacement = up ? text.uppercased() : text.lowercased()

			insertText(replacement, replacementRange: selectionRange)
		}
	}

	func move(out: Bool) {
		gCreateCombinedEssay = true
		let        selection = selectedNotes

		save()

		if !out, let last = selection.last {
			resetCurrentEssay(last)
		} else if out {
			gNoteAndEssay.grabbedZone?.traverseAncestors { ancestor -> (ZTraverseStatus) in
				if  ancestor != gNoteAndEssay.grabbedZone, ancestor.hasEssay {
					self.resetCurrentEssay(ancestor.note)

					return .eStop
				}

				return .eContinue
			}
		}
	}

	private func select(restoreSelection: Int? = nil) {
		if  let e = gCurrentEssay, (e.lastTextIsDefault || restoreSelection != nil),
			var range      = e.lastTextRange {			// select entire text of final essay
			if  let offset = restoreSelection {
				range      = NSRange(location: offset, length: 0)
			}

			setSelectedRange(range)
		} else {
			scroll(CGPoint())					// scroll to top
		}
	}

	func accountForSelection() {
		var needsUngrab = true

		for note in selectedNotes {
			if  let grab = note.zone {
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
		NSMenu.specialsPopup(target: self, action: #selector(handleSpecialsPopupMenu(_:))).popUp(positioning: nil, at: selectionRect.origin, in: self)
	}

	@objc private func handleSpecialsPopupMenu(_ iItem: ZMenuItem) {
		if  let  type = ZSpecialsMenuType(rawValue: iItem.keyEquivalent),
			type     != .eCancel {
			let  text = type.text

			insertText(text, replacementRange: selectionRange)
		}
	}

	// MARK:- buttons
	// MARK:-

	enum ZTextButtonID : Int {
		case idForward
		case idCancel
		case idDelete
		case idBack
		case idSave
		case idHide

		var title: String {
			switch self {
				case .idForward: return "􀓅"
				case .idCancel:  return "Cancel"
				case .idDelete:  return "Delete"
				case .idHide:    return "Hide"
				case .idSave:    return "Save"
				case .idBack:    return "􀓄"
			}
		}

		static var all: [ZTextButtonID] { return [.idBack, .idForward, .idHide, .idSave, .idCancel, .idDelete] }
	}

	func updateButtons(_ flag: Bool) {
		hideButton?    .isEnabled = flag
		saveButton?    .isEnabled = flag
		cancelButton?  .isEnabled = flag
		deleteButton?  .isEnabled = flag
		forwardButton? .isEnabled = flag
		backwardButton?.isEnabled = flag
	}

	private func setButton(_ button: ZButton) {
		if let tag = ZTextButtonID(rawValue: button.tag) {
			switch tag {
				case .idForward: forwardButton = button
				case .idCancel:   cancelButton = button
				case .idDelete:   deleteButton = button
				case .idBack:   backwardButton = button
				case .idHide:       hideButton = button
				case .idSave:       saveButton = button
			}
		}
	}

	@objc private func handleButtonPress(_ iButton: ZButton) {
		if let buttonID = ZTextButtonID(rawValue: iButton.tag) {
			switch buttonID {
				case .idForward: gEssayRing.goForward()
				case .idDelete:  gCurrentEssay?.delete(); 			exit()
				case .idCancel:  gNoteAndEssay.grabbedZone?.grab(); exit()
				case .idHide:    gNoteAndEssay.grabbedZone?.grab(); done()
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
		case eNote  = "n"
		case eEssay = "e"
		case eClear = "c"

		var title: String {
			switch self {
				case .eWeb:   return "Internet"
				case .eIdea:  return "Idea"
				case .eNote:  return "Note"
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

		static var all: [ZHyperlinkMenuType] { return [.eWeb, .eIdea, .eNote, .eEssay, .eClear] }

	}

	private func showHyperlinkPopup() {
		let menu = NSMenu(title: "create a hyperlink")
		menu.autoenablesItems = false

		for type in ZHyperlinkMenuType.all {
			menu.addItem(item(type: type))
		}

		menu.popUp(positioning: nil, at: selectionRect.origin, in: self)
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
				case .eWeb:   link = gEssayController?.modalForWebLink(textStorage?.string.substring(with: selectionRange))
				default:      if let b = gSelecting.pastableRecordName { link?.append(b) } else { return }
			}

			if  link == nil {
				textStorage?.removeAttribute(.link,               range: selectionRange)
			} else {
				textStorage?   .addAttribute(.link, value: link!, range: selectionRange)
			}
		}
	}

	var selectedNotes: [ZNote] {
		var array = [ZNote]()

		if  let zones = gNoteAndEssay.grabbedZone?.zonesWithNotes {
			for zone in zones {
				if  let note = zone.noteMaybe, note.noteRange.inclusiveIntersection(selectionRange) != nil {
					array.append(note)
				}
			}
		}

		if  let e = gNoteAndEssay.grabbedZone?.note,
			array.count == 0 {
			array.append(e)
		}

		return array
	}

	var currentLink: Any? {
		var found: Any?
		var range = selectionRange

		if  let       length = textStorage?.length,
		    range.upperBound < length,
			range.length    == 0 {
			range.length     = 1
		}

		textStorage?.enumerateAttribute(.link, in: range, options: .reverse) { (item, inRange, flag) in
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
					case .eIdea:
						if  let   grab = zone {
							let common = gNoteAndEssay.grabbedZone?.closestCommonParent(of: grab)

							if  let  c = common {
								gHere  = c
							}

							grab                      .grab()												// focus on zone with rID
							grab                      .asssureIsVisible()
							gNoteAndEssay.grabbedZone?.asssureIsVisible()

							FOREGROUND {
								gControllers.swapGraphAndEssay()
								self.redrawGraph()
							}

							return true
						}
					case .eEssay, .eNote:
						if  let target = zone {
							let common = gNoteAndEssay.grabbedZone?.closestCommonParent(of: target)

							if  let  c = common {
								gHere  = c
							}

							FOREGROUND {
								if  let  note = target.noteMaybe, gCurrentEssay?.children.contains(note) ?? false {
									let range = note.offsetTextRange	// text range of target essay
									let start = NSRange(location: range.location, length: 1)
									let  rect = self.convert(self.rectForRange(start), to: self).offsetBy(dx: 0.0, dy: -150.0)

									// highlight text of note, and scroll it to visible

									self.setSelectedRange(range)
									self.scroll(rect.origin)
								} else {
									gCreateCombinedEssay = type == .eEssay

									target .grab()					// for later, when user exits essay mode
									target .asssureIsVisible()
									common?.asssureIsVisible()
									self.resetCurrentEssay(target.note)     // change current note to that of target
								}
							}

							return true
						}
					default: break
				}
			}
		}

		return false
	}

	func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
		return followCurrentLink(within: NSRange(location: charIndex, length: 0))
	}

	func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRange oldRange: NSRange, toCharacterRange newRange: NSRange) -> NSRange {
		selectionRange = newRange

		return newRange
	}

	// MARK:- lockout editing of added whitespace
	// MARK:-

	func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString replacement: String?) -> Bool {
		if  let length = replacement?.length,
			let (result, delta) = gCurrentEssay?.shouldAlterEssay(range, length: length) {

			switch result {
				case .eAlter: return true
				case .eLock:  return false
				case .eExit:  gControllers.swapGraphAndEssay()
				case .eDelete:
					FOREGROUND {										// defer until after this method returns ... avoids corrupting resulting text
						gCurrentEssay?.reset()
						self.updateText(restoreSelection: delta)		// recreate essay text and restore cursor position within it
				}
			}

			gCurrentEssay?.essayLength += delta							// compensate for change

			return true
		}

		return replacement == nil // does this return value matter?
	}

}

