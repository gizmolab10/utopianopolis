//
//  ZEssayView.swift
//  Seriously
//
//  Created by Jonathan Sand on 12/22/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
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
	let dotRadius       = CGFloat(-5.0)
	var dropped         = [String]()
	var selectionRange  = NSRange()          { didSet { if selectionRange.location != 0, let rect = rectForRange(selectionRange) { selectionRect = rect } } }
	var selectionRect   = CGRect()           { didSet { if selectionRect.origin != CGPoint.zero { imageAttachment = nil } } }
	var imageAttachment : ZRangedAttachment? { didSet { if imageAttachment != nil { selectionRange = NSRange() } else if oldValue != nil { eraseAttachment = oldValue } } }
	var eraseAttachment : ZRangedAttachment?
	var selectionZone   : Zone?              { return selectedNotes.first?.zone }
	var selectionString : String?            { return textStorage?.attributedSubstring(from: selectionRange).string }
	var backwardButton  : ZButton?
	var forwardButton   : ZButton?
	var cancelButton    : ZButton?
	var deleteButton    : ZButton?
	var hideButton      : ZButton?
	var saveButton      : ZButton?
	var resizeDragStart : CGPoint?
	var resizeDragRect  : CGRect?
	var resizeDot       : ZDirection?
	var essayID         : CKRecord.ID?

	var shouldOverwrite: Bool {
		if  let          current = gCurrentEssay,
			current.noteTraitMaybe?.needsSave ?? false,
			current.essayLength != 0,
			let               i  = gCurrentEssayZone?.record?.recordID,
			i                   == essayID {	// been here before

			return false						// has not yet been saved. don't overwrite
		}

		return true
	}

	// MARK:- input
	// MARK:-

	func handleKey(_ iKey: String?, flags: ZEventFlags) -> Bool {   // false means key not handled
		guard let key = iKey else {
			return false
		}

		let COMMAND = flags.isCommand
		let CONTROL = flags.isControl
		let  OPTION = flags.isOption
		let     ALL = OPTION && CONTROL

		if  COMMAND {
			switch key {
				case "a":      selectAll(nil)
				case "d":      convertToChild(createEssay: ALL)
				case "e":      grabSelectedTextForSearch()
				case "f":      gSearching.showSearch(OPTION)
				case "g":      searchAgain(OPTION)
				case "i":      showSpecialsPopup()
				case "l":      alterCase(up: false)
				case "n":      swapBetweenNoteAndEssay()
				case "p":      printCurrentEssay()
				case "s":      save()
				case "t":      if OPTION { gControllers.showEssay(forGuide: false) } else { return false }
				case "u":      if OPTION { gControllers.showEssay(forGuide:  true) } else { alterCase(up: true) }
				case "/":                  gHelpController?.show(flags: flags)
				case "]", "[": gEssayEditor.smartGo(forward: key == "]")
				case kReturn:  gCurrentEssayZone?.grab(); done()
				default:       return false
			}

			return true
		} else if CONTROL {
			switch key {
				case "d":      convertToChild(createEssay: true)
				case "h":      showHyperlinkPopup()
				case "/":      popNoteAndUpdate()
				default:       return false
			}

			return true
		}

		return false
	}

	override func mouseDown(with event: ZEvent) {
		if  !handleClick   (with: event) {
			super.mouseDown(with: event)
		}
	}

	func handleClick(with event: ZEvent) -> Bool {
		let            rect = rectFromEvent(event)
		if  let      attach = attachmentHit(at: rect) {
			resizeDot       = resizeDotHit(in: attach, at: rect)
			resizeDragStart = rect.origin
			imageAttachment = attach

			return resizeDot != nil // true means do not further process this event
		}

		clearResizing()
		setNeedsDisplay()

		return false
	}

	// change cursor to indicate action possible on what's under cursor

	override func mouseMoved(with event: ZEvent) {
		let  rect = rectFromEvent(event)

		NSCursor.iBeam.set()

		if  linkHit(at: rect) {
			NSCursor.arrow.set()
		} else if let item = attachmentHit(at: rect),
			let  imageRect = rectForRangedAttachment(item) {

			NSCursor.openHand.set()

			for point in imageRect.selectionPoints.values {
				let cornerRect = CGRect(origin: point, size: CGSize.zero).insetEquallyBy(dotRadius)

				if  cornerRect.intersects(rect) {
					NSCursor.crosshair.set()
				}
			}
		}
	}

	// MARK:- resize image
	// MARK:-

	func clearResizing() {
		imageAttachment = nil
		resizeDragStart = nil
		resizeDragRect  = nil
		resizeDot       = nil
	}

	override func mouseDragged(with event: ZEvent) {
		if  resizeDot != nil,
			let  start = resizeDragStart {
			let  delta = rectFromEvent(event).origin - start

			updateDragRect(for: delta)
			setNeedsDisplay()
		}
	}

	override func mouseUp(with event: ZEvent) {
		if  resizeDot != nil,
			updateImage(),
			let attach = imageAttachment {
			let  range = attach.range

			save()
			clearResizing()
			setNeedsLayout()
			setNeedsDisplay()
			updateText(restoreSelection: range.location)
		}
	}

	func updateImage() -> Bool {
		if  let    size  = resizeDragRect?.size,
			let       a  = imageAttachment?.attachment,
			let   image  = a.image {
			let oldSize  = image.size
			if  oldSize != size {
				a.image  = image.resizedTo(size)

				return true
			}
		}

		return false
	}

	func updateDragRect(for delta: CGSize) {

		// compute imageDragRect from delta.width, image rect and corner
		// preserving aspect ratio

		if  let direction = resizeDot,
			let    attach = imageAttachment,
			let      rect = rectForRangedAttachment(attach) {
			var      size = rect.size
			var    origin = rect.origin
			let  fraction = size.fraction(delta)
			let     wGrow = size.width  * (1.0 - fraction.width)
			let     hGrow = size.height * (1.0 - fraction.height)

			switch direction {
				case .topLeft:     size   = size  .offsetBy(-wGrow, -hGrow)
				case .bottomLeft:  size   = size  .offsetBy(-wGrow,  hGrow)
				case .topRight:    size   = size  .offsetBy( wGrow, -hGrow)
				case .bottomRight: size   = size  .offsetBy( wGrow,  hGrow)
				case .left:        size   = size  .offsetBy(-wGrow,  0.0)
				case .right:       size   = size  .offsetBy( wGrow,  0.0)
				case .top:         size   = size  .offsetBy( 0.0,   -hGrow)
				case .bottom:      size   = size  .offsetBy( 0.0,    hGrow)
			}

			switch direction {
				case .topLeft:     origin = origin.offsetBy( wGrow,  hGrow)
				case .top,
					 .topRight:    origin = origin.offsetBy( 0.0,    hGrow)
				case .left,
					 .bottomLeft:  origin = origin.offsetBy( wGrow,  0.0)
				default:           break
			}

			resizeDragRect = CGRect(origin: origin, size: size)
		}
	}

	// MARK:- output
	// MARK:-

	override func draw(_ dirtyRect: NSRect) {
		if  resizeDragRect == nil {
			let path = ZBezierPath(rect: bounds)

			kClearColor.setFill()
			path.fill() // erase rubberband
		}

		super.draw(dirtyRect)

		if  imageAttachment != nil {
			gActiveColor.setStroke()
			gActiveColor.setFill()
		} else {
			kClearColor     .setStroke()
			kClearColor     .setFill()
		}

		if  let       rect = resizeDragRect {
			let       path = ZBezierPath(rect: rect)
			let    pattern : [CGFloat] = [4.0, 4.0]
			path.lineWidth = CGFloat(gLineThickness * 3.0)
			path.flatness  = 0.0001

			path.setLineDash(pattern, count: 2, phase: 4.0)
			path.stroke()
			drawDots(in: rect)
		} else if let attach = imageAttachment ?? eraseAttachment,
			let         rect = rectForRangedAttachment(attach) {
			drawDots(in: rect)
		}
	}

	func drawDots(in rect: CGRect) {
		for point in rect.selectionPoints.values {
			let   dotRect = CGRect(origin: point, size: CGSize.zero).insetEquallyBy(dotRadius)
			let      path = ZBezierPath(ovalIn: dotRect)
			path.flatness = 0.0001

			path.fill()
		}
	}

	// MARK:- setup
	// MARK:-

	func done() { save(); exit() }

	func exit() {
		if  let e = gCurrentEssay {
			gControllers.swapGraphAndEssay(force: .graphMode)
			gRedrawGraph()

			if  e.lastTextIsDefault,
				e.autoDelete {
				e.zone?.destroyNote()
			}

			gSignal([.sDatum])
		}
	}

	func save() {
		if  let e = gCurrentEssay {
			e.saveEssay(textStorage)
			accountForSelection()
		}
	}

	override func awakeFromNib() {
		super.awakeFromNib()

		usesRuler              = true
		isRulerVisible         = true
		usesInspectorBar       = true
		allowsImageEditing     = true
		textContainerInset     = NSSize(width: 20, height: 0)
		zlayer.backgroundColor = kClearColor.cgColor
		backgroundColor        = kClearColor

		addButtons()
		updateText()
	}

	private func clear() {
		gCurrentEssayZone?.noteMaybe = nil
		delegate = nil		// clear so that shouldChangeTextIn won't be invoked on insertText or replaceCharacters

		if  let length = textStorage?.length, length > 0 {
			textStorage?.replaceCharacters(in: NSRange(location: 0, length: length), with: "")
		}
	}

	func resetForDarkMode() {
//		layer?.backgroundColor = (gIsDark ? kDarkestGrayColor : kWhiteColor).cgColor
	}

	func resetCurrentEssay(_ current: ZNote?, selecting range: NSRange? = nil) {
		if  let      note = current {
			gCurrentEssay = note

			gCurrentEssay?.reset()
			updateText()
			gCurrentEssay?.updateOffsets()
			gRecents.push(intoNotes: true)

			if  let r = range {
				FOREGROUND {
					self.setSelectedRange(r)
				}
			}
		}
	}

	func updateText(restoreSelection: Int?  = nil) {
		resetForDarkMode()

		if  (shouldOverwrite || restoreSelection != nil),
			let text = gCurrentEssay?.essayText {
			clear() 								// discard previously edited text
			updateControlBarButtons(true)
			gCurrentEssay?.noteTrait?.setCurrentTrait { setText(text) }		// emplace text
			select(restoreSelection: restoreSelection)

			essayID  = gCurrentEssayZone?.record?.recordID
			delegate = self 						// set delegate after setText

			if  gIsNoteMode {
				gMainWindow?.makeFirstResponder(self) // this should never happen unless alread in note mode
			}
		}
	}

	// MARK:- private
	// MARK:-

	func searchAgain(_ OPTION: Bool) {
	    let    seek = gSearching.searchText
		var  offset = selectionRange.upperBound + 1
		let    text = gCurrentEssay?.essayText?.string
		let   first = text?.substring(toExclusive: offset)
		let  second = text?.substring(fromInclusive: offset)
		var matches = second?.rangesMatching(seek)

		if  matches == nil || matches!.count == 0 {
			matches = first?.rangesMatching(seek) // wrap around
			offset  = 0
		}

		if  matches != nil,
			matches!.count > 0 {
			selectionRange = matches![0].offsetBy(offset)

			scrollToVisible(selectionRect)
			setSelectedRange(selectionRange)
		}
	}

	func grabSelectedTextForSearch() {
		gSearching.searchText = selectionString
	}

	func linkHit(at rect: CGRect) -> Bool {
		if  let array = textStorage?.linkRanges {
			for range in array {
				let linkRects = rectsForRange(range)
				let count = linkRects.count

				if  count > 0 {
					for index in 0 ..< count {
						let lineRect = linkRects[index]

						if  range.length    < 150,
							lineRect.width  < 250.0,
							lineRect.height <  25.0,
							lineRect.intersects(rect) {
							return true
						}
					}
				}
			}
		}

		return false
	}

	func attachmentHit(at rect: CGRect) -> ZRangedAttachment? {
		if  let array = textStorage?.rangedAttachments {
			for item in array {
				if  let imageRect = rectForRangedAttachment(item)?.insetEquallyBy(dotRadius),
					imageRect.intersects(rect) {

					return item
				}
			}
		}

		return nil
	}

	func resizeDotHit(in attach: ZRangedAttachment?, at rect: CGRect) -> ZDirection? {
		if  let      item = attach,
			let imageRect = rectForRangedAttachment(item) {
			let    points = imageRect.selectionPoints

			for dot in points.keys {
				if  let point = points[dot] {
					let selectionRect = CGRect(origin: point, size: CGSize.zero).insetEquallyBy(dotRadius)

					if  selectionRect.intersects(rect) {
						return dot
					}
				}
			}
		}

		return nil
	}

	func rectForRangedAttachment(_ attach: ZRangedAttachment) -> CGRect? {
		if  let      managers = textStorage?.layoutManagers, managers.count > 0 {
			let layoutManager = managers[0] as NSLayoutManager
			let    containers = layoutManager.textContainers

			if  containers.count > 0 {
				let textContainer = containers[0]
				var    glyphRange = NSRange()

				layoutManager.characterRange(forGlyphRange: attach.range, actualGlyphRange: &glyphRange)
				return layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer).offsetBy(dx: 20.0, dy: 0.0)
			}
		}

		return nil
	}

	func swapBetweenNoteAndEssay() {
		if  let          current = gCurrentEssay,
			let             zone = current.zone {
			gCreateCombinedEssay = current.isNote
			let            count = zone.countOfNotes

			if  gCreateCombinedEssay {
				if  count > 1 {
					resetCurrentEssay(zone.note)
				}
			} else if count > 0,
				let note = zone.currentNote {
				resetCurrentEssay(note)
			}
		}
	}

	func popNoteAndUpdate() {
		if  gRecents.pop(fromNotes: true) {
			exit()
		} else {
			updateText()
		}
	}

	private func convertToChild(createEssay: Bool = false) {
		if  let   text = selectionString, text.length > 0,
			let   dbID = gCurrentEssayZone?.databaseID,
			let parent = selectionZone {
			let  child = Zone(databaseID: dbID, named: text)    		// create new (to be child) zone from text

			insertText("", replacementRange: selectionRange)			// remove text
			parent.addChild(child)
			child.asssureIsVisible()
			save()

			if  createEssay {
				child.setTraitText(kEssayDefault, for: .tNote)			// create a placeholder essay in the child
				gCurrentEssayZone?.createNote()

				resetCurrentEssay(gCurrentEssayZone?.note, selecting: child.noteMaybe?.offsetTextRange)	// redraw essay TODO: WITH NEW NOTE SELECTED
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
			gCurrentEssayZone?.traverseAncestors { ancestor -> (ZTraverseStatus) in
				if  ancestor != gCurrentEssayZone, ancestor.hasNote {
					self.resetCurrentEssay(ancestor.note)

					return .eStop
				}

				return .eContinue
			}
		}

		gSignal([.sCrumbs])
	}

	private func select(restoreSelection: Int? = nil) {
		var point = CGPoint()                     // scroll to top

		if  let e = gCurrentEssay,
			(e.lastTextIsDefault || restoreSelection != nil),
			var range      = e.lastTextRange {    // select entire text of final essay
			if  let offset = restoreSelection {
				range      = NSRange(location: offset, length: 0)
			}

			if  let   r = rectForRange(range) {
				point   = r.origin
				point.y = max(0.0, point.y - 100.0)
			}

			setSelectedRange(range)
		}

		scroll(point)
	}

	func accountForSelection() {
		var needsUngrab = true

		for note in selectedNotes {
			if  let grab = note.zone {
				if  needsUngrab {
					needsUngrab = false
				}

				grab.asssureIsVisible()
			}
		}
	}

	// MARK:- special characters
	// MARK:-

	private func showSpecialsPopup() {
		NSMenu.symbolsPopup(target: self, action: #selector(handleSymbolsPopupMenu(_:))).popUp(positioning: nil, at: selectionRect.origin, in: self)
	}

	@objc private func handleSymbolsPopupMenu(_ iItem: ZMenuItem) {
		if  let  type = ZSymbolsMenuType(rawValue: iItem.keyEquivalent),
			type     != .eCancel {
			let  text = type.text

			insertText(text, replacementRange: selectionRange)
		}
	}

	// MARK:- buttons
	// MARK:-

	func updateControlBarButtons(_ flag: Bool) {
		backwardButton?.isEnabled = flag
		forwardButton? .isEnabled = flag
		deleteButton?  .isEnabled = flag
		cancelButton?  .isEnabled = flag
		hideButton?    .isEnabled = flag
		saveButton?    .isEnabled = flag
	}

	private func setButton(_ button: ZButton) {
		if let tag = ZEssayButtonID(rawValue: button.tag) {
			switch tag {
				case .idBack:   backwardButton = button
				case .idForward: forwardButton = button
				case .idCancel:   cancelButton = button
				case .idDelete:   deleteButton = button
				case .idHide:       hideButton = button
				case .idSave:       saveButton = button
			}
		}
	}

	@objc private func handleButtonPress(_ iButton: ZButton) {
		if let buttonID = ZEssayButtonID(rawValue: iButton.tag) {
			switch buttonID {
				case .idForward: gEssayEditor.smartGo(forward:  true, amongNotes: true)
				case .idBack:    gEssayEditor.smartGo(forward: false, amongNotes: true)
				case .idSave:    save()
				case .idHide:    gCurrentEssayZone?.grab();        done()
				case .idCancel:  gCurrentEssayZone?.grab();        exit()
				case .idDelete:  gCurrentEssayZone?.destroyNote(); exit()
			}
		}
	}

	private func addButtons() {
		FOREGROUND { // wait for application to fully load the inspector bar
			if  let            w = gMainWindow,
				let inspectorBar = w.titlebarAccessoryViewControllers.first(where: { $0.view.className == "__NSInspectorBarView" } )?.view {

				func button(for tag: ZEssayButtonID) -> ZButton {
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

				for tag in ZEssayButtonID.all {
					let b = button(for: tag)

					inspectorBar.addSubview(b)
					self.setButton(b)
				}
			}
		}
	}

	// MARK:- hyperlinks
	// MARK:-

	private func showHyperlinkPopup() {
		let menu = NSMenu(title: "create a hyperlink")
		menu.autoenablesItems = false

		for type in ZEssayHyperlinkType.all {
			menu.addItem(item(type: type))
		}

		menu.popUp(positioning: nil, at: selectionRect.origin, in: self)
	}

	private func item(type: ZEssayHyperlinkType) -> NSMenuItem {
		let  	  item = NSMenuItem(title: type.title, action: #selector(handleHyperlinkPopupMenu(_:)), keyEquivalent: type.rawValue)
		item   .target = self
		item.isEnabled = true

		item.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: 0)

		return item
	}

	@objc private func handleHyperlinkPopupMenu(_ iItem: ZMenuItem) {
		if  let type = ZEssayHyperlinkType(rawValue: iItem.keyEquivalent) {
			var link: String? = type.linkType + kColonSeparator

			switch type {
				case .hClear: link = nil // to remove existing hyperlink
				case .hWeb:   link = gEssayController?.modalForHyperlink(textStorage?.string.substring(with: selectionRange))
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

		if  let zones = gCurrentEssayZone?.zonesWithNotes {
			for zone in zones {
				if  let note = zone.noteMaybe, note.noteRange.inclusiveIntersection(selectionRange) != nil {
					array.append(note)
				}
			}
		}

		if  let e = gCurrentEssayZone?.note,
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
			let parts = link.components(separatedBy: kColonSeparator)

			if  parts.count > 1,
				let    t = parts.first?.first,                          // first character of first part
				let  rID = parts.last,
				let type = ZEssayHyperlinkType(rawValue: String(t)) {
				let zone = gSelecting.zone(with: rID)	                // find zone with rID
				switch type {
					case .hIdea:
						if  let  grab = zone {
							gHere     = grab
							let eZone = gCurrentEssayZone

							grab  .grab()			                    // focus on zone with rID
							grab  .asssureIsVisible()
							eZone?.asssureIsVisible()

							FOREGROUND {
								gControllers.swapGraphAndEssay(force: .graphMode)
								gRedrawGraph()
							}

							return true
						}
					case .hEssay, .hNote:
						if  let target = zone {
							let common = gCurrentEssayZone?.closestCommonParent(of: target)

							if  let  c = common {
								gHere  = c
							}

							FOREGROUND {
								if  let  note = target.noteMaybe, gCurrentEssay?.children.contains(note) ?? false {
									let range = note.offsetTextRange	// text range of target essay
									let start = NSRange(location: range.location, length: 1)

									self.setSelectedRange(range)

									if  let    r = self.rectForRange(start) {
										let rect = self.convert(r, to: self).offsetBy(dx: 0.0, dy: -150.0)

										// highlight text of note, and scroll it to visible

										self.scroll(rect.origin)
									}
								} else {
									gCreateCombinedEssay = type == .hEssay

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

	// MARK:- drop images
	// MARK:-

	override func draggingEntered(_ drag: NSDraggingInfo) -> NSDragOperation {
		if  let    board = drag.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
			let     path = board[0] as? String {
			let fileName = URL(fileURLWithPath: path).lastPathComponent
			printDebug(.dImages, "DROP     \(fileName)")
			dropped.append(fileName)
		}

		return .copy
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
