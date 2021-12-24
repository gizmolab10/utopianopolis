//
//  ZEssayView.swift
//  Seriously
//
//  Created by Jonathan Sand on 12/22/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

import CloudKit
import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

var gEssayView: ZEssayView? { return gEssayController?.essayView }

struct ZEssayDragDot {
	var     color = kWhiteColor
	var  dragRect = CGRect.zero
	var  textRect = CGRect.zero
	var  lineRect : CGRect?
	var noteRange : NSRange?
	var      note : ZNote?
}

@objc (ZEssayView)
class ZEssayView: ZTextView, ZTextViewDelegate {
	let margin          = CGFloat(20.0)
	let dotInset        = CGFloat(-5.0)
	var dropped         = StringsArray()
	var grabbedNotes    = [ZNote]()
	var selectionRect   = CGRect()           { didSet { if selectionRect.origin == .zero { imageAttachment = nil } } }
	var imageAttachment : ZRangedAttachment? { didSet { if imageAttachment != nil { setSelectedRange(NSRange()) } else if oldValue != nil { eraseAttachment = oldValue } } }
	var eraseAttachment : ZRangedAttachment?
	var grabbedZones    : [Zone]             { return grabbedNotes.map { $0.zone! } }
	var firstNote       : ZNote?             { return (dragDots.count == 0) ? nil : dragDots[0].note }
	var selectedNote    : ZNote?             { return selectedNotes.last ?? gCurrentEssay }
	var selectedZone    : Zone?              { return selectedNote?.zone }
	var firstGrabbedNote: ZNote?             { return hasGrabbedNote ? grabbedNotes[0] : nil }
	var firstGrabbedZone: Zone?              { return firstGrabbedNote?.zone }
	var hasGrabbedNote  : Bool               { return grabbedNotes.count != 0 }
	var lockedSelection : Bool               { return gCurrentEssay?.isLocked(within: selectedRange) ?? false }
	var firstIsGrabbed  : Bool               { return hasGrabbedNote && firstGrabbedZone == firstNote?.zone }
	var selectionString : String?            { return textStorage?.attributedSubstring(from: selectedRange).string }
	var backwardButton  : ZButton?
	var forwardButton   : ZButton?
	var cancelButton    : ZButton?
	var deleteButton    : ZButton?
	var hideButton      : ZButton?
	var saveButton      : ZButton?
	var resizeDragStart : CGPoint?
	var resizeDragRect  : CGRect?
	var resizeDot       : ZDirection?
	var essayRecordName : String?

	@IBOutlet var titlesControl : ZSegmentedControl?
	var selectedNotes : [ZNote] {
		return (gCurrentEssay?.zone?.zonesWithNotes.filter {
			$0.note?.noteRange != nil &&
			selectedRange.intersects($0.note!.noteRange.extendedBy(1))
		}.map {
			$0.note!
		})!
	}

	var shouldOverwrite: Bool {
		if  let          current = gCurrentEssay,
			current.essayLength != 0,
			let i                = gCurrentEssayZone?.recordName,
			i                   == essayRecordName {	// been here before

			return false						// has not yet been saved. don't overwrite
		}

		return true
	}

	var relativeLevelOfFirstGrabbed: Int {
		if  let    e = gCurrentEssayZone,
			let    f = firstGrabbedZone {
			return f.level - e.level
		}

		return 0
	}

	// MARK: - output
	// MARK: -

	override func draw(_ dirtyRect: NSRect) {
		let attach = imageAttachment ?? eraseAttachment

		clearImageResizeRubberband()
		super.draw(dirtyRect)

		if  attach != nil {
			gActiveColor.setStroke()
			gActiveColor.setFill()
		} else {
			kClearColor .setStroke()
			kClearColor .setFill()
		}

		drawImageResizeDots(around: attach)

		if  gEssayTitleMode == .sFull {
			drawDragDecorations()
		}
	}

	// MARK: - input
	// MARK: -

	@discardableResult func handleKey(_ iKey: String?, flags: ZEventFlags) -> Bool {   // false means key not handled
		guard var key = iKey else {
			return false
		}

		let enabled = gProducts.hasEnabledSubscription || true
		let SPECIAL = flags.exactlySpecial
		let COMMAND = flags.isCommand
		let CONTROL = flags.isControl
		let OPTION  = flags.isOption
		var SHIFT   = flags.isShift
		let SEVERAL = flags.isAnyMultiple
		let ANY     = flags.isAny
		if  key    != key.lowercased() {
			key     = key.lowercased()
			SHIFT   = true
		}

		if  let arrow = key.arrow {
			clearResizing()
			handleArrow(arrow, flags: flags)

			return true
		} else if  hasGrabbedNote {
			switch key {
				case "c":      grabbedZones.copyToPaste()
				case "t":      swapWithParent()
				case "'":      gToggleSmallMapMode(OPTION)
				case "/":      if SPECIAL { gHelpController?.show(flags: flags) } else { swapBetweenNoteAndEssay() }
				case kEquals:  if   SHIFT { grabSelected()                      } else { return followLinkInSelection() }
				case kEscape:  if     ANY { grabDone()                          } else { done() }
				case kReturn:  if     ANY { grabDone() }
				case kDelete:  deleteGrabbed()
				default:       return false
			}

			return true
		} else if key == kEscape {
			if  OPTION {
				asssureSelectionIsVisible()
			}

			if  ANY {
				grabSelectionHereDone()
			} else {
				done()
			}

			return true
		} else if COMMAND {
			if  enabled {
				switch key {
					case "b":  applyToSelection(BOLD: true)
					case "d":  convertToChild(flags)
					case "e":  grabSelectedTextForSearch()
					case "f":  gSearching.showSearch(OPTION)
					case "g":  searchAgain(OPTION)
					case "i":  showSpecialCharactersPopup()
					case "l":  alterCase(up: false)
					case "p":  printCurrentEssay()
					case "s":  save()
					case "u":  if !OPTION { alterCase(up: true) }
					case "z":  if  SHIFT  { undoManager?.redo() } else { undoManager?.undo() }
					default:   break
				}
			}

			switch key {
				case "a":      selectAll(nil)
				case "n":      swapBetweenNoteAndEssay()
				case "t":      if let string = selectionString { showThesaurus(for: string) } else if OPTION { gControllers.showEssay(forGuide: false) } else { return false }
				case "u":      if OPTION { gControllers.showEssay(forGuide:  true) }
				case "/":      gHelpController?.show(flags: flags)
				case "'":      gToggleSmallMapMode(OPTION)
				case "}", "{": gCurrentSmallMapRecords?.go(down: key == "}", amongNotes: true) { gRelayoutMaps() }
				case "]", "[": gRecents                .go(down: key == "]", amongNotes: true) { gRelayoutMaps() }
				case kReturn:  if SEVERAL { grabSelectionHereDone() } else { grabDone() }
				case kEquals:  if   SHIFT { grabSelected() } else { return followLinkInSelection() }
				default:       return false
			}

			return true
		} else if CONTROL {
			if  enabled {
				switch key {
					case "d":  convertToChild(flags)
					case "w":  showLinkPopup()
					default:   break
				}
			}

			switch key {
				case "/":      popNoteAndUpdate()
				default:       return false
			}

			return true
		} else if OPTION, enabled {
			switch key {
				case "d":      convertToChild(flags)
				default:       return false
			}

			return true
		}

		return !enabled
	}

	func handleArrow(_ arrow: ZArrowKey, flags: ZEventFlags) {
		let   SHIFT = flags.isShift
		let  OPTION = flags.isOption
		let COMMAND = flags.isCommand
		let SPECIAL = flags.exactlySpecial

		if  hasGrabbedNote {
			handleGrabbed(arrow, flags: flags)
		} else if  SPECIAL {
			switch arrow {
				case .left,
					 .right: move(out: arrow == .left)
				default:     break
			}
		} else if  COMMAND && SHIFT {
			switch arrow {
				case .up:    moveToBeginningOfDocumentAndModifySelection(nil)
				case .down:  moveToEndOfDocumentAndModifySelection(nil)
				case .left:  moveToLeftEndOfLineAndModifySelection(nil)
				case .right: moveToRightEndOfLineAndModifySelection(nil)
			}
		} else if  COMMAND {
			switch arrow {
				case .up:    moveToBeginningOfParagraph(nil)
				case .down:  moveToEndOfParagraph(nil)
				case .left:  moveToBeginningOfLine(nil)
				case .right: moveToEndOfLine(nil)
			}
		} else if  OPTION && SHIFT {
			switch arrow {
				case .up:    moveToBeginningOfParagraphAndModifySelection(nil)
				case .down:  moveToEndOfParagraphAndModifySelection(nil)
				case .left:  moveWordLeftAndModifySelection(nil)
				case .right: moveWordRightAndModifySelection(nil)
			}
		} else if  SHIFT {
			switch arrow {
				case .up:    moveUpAndModifySelection(nil)
				case .down:  moveDownAndModifySelection(nil)
				case .left:  moveLeftAndModifySelection(nil)
				case .right: moveRightAndModifySelection(nil)
			}
		} else if  OPTION {
			switch arrow {
				case .up:    moveToLeftEndOfLine(nil)
				case .down:  moveToRightEndOfLine(nil)
				case .left:  moveWordBackward(nil)
				case .right: moveWordForward(nil)
			}
		} else {
			handlePlainArrow(arrow)
		}

		setNeedsDisplay() // to update which drag dot is filled
	}

	func handlePlainArrow(_ arrow: ZArrowKey, permitAnotherRecurse: Bool = true) {
		let horizontal = [.left, .right].contains(arrow)
		var canRecurse = true

		switch arrow {
			case .up:    moveUp(nil)
			case .down:  moveDown(nil)
			case .left:  moveLeft(nil)
			case .right: moveRight(nil)
		}

		switch arrow {
			case .left:  canRecurse = selectedRange.lowerBound > 0
			case .right: canRecurse = selectedRange.upperBound < gCurrentEssay?.upperBoundForNoteIn(selectedRange) ?? 0
			default:     break
		}

		switch arrow {
			case .left,
				 .right: setSelectedRange(selectedRange)     // work around stupid Apple bug
			default:     break
		}


		if  permitAnotherRecurse, canRecurse, lockedSelection {
			handlePlainArrow(arrow, permitAnotherRecurse: horizontal)
		}
	}

	func handleClick(with event: ZEvent) -> Bool {
		let              rect = rectFromEvent(event)
		if  let        attach = hitTestForAttachment(in: rect) {
			resizeDot         = hitTestForResizeDot(in: rect, for: attach)
			resizeDragStart   = rect.origin
			imageAttachment   = attach

			setSelectedRange(attach.range)
			setNeedsDisplay()

			return resizeDot != nil // true means do not further process this event
		} else if let     dot = dragDotHit(at: rect),
				  let    note = dot.note {
			if  let     index = grabbedNotes.firstIndex(of: note) {
				grabbedNotes.remove(at: index)
			} else {
				if !event.modifierFlags.isShift {
					ungrabAll()
				}

				grabbedNotes.appendUnique(item: note)
				setNeedsDisplay()
				gSignal([.sDetails])
			}

			return true
		} else {
			ungrabAll()
			clearResizing()
			setNeedsDisplay()

			return false
		}
	}

	override func mouseDown(with event: ZEvent) {
		if  !handleClick   (with: event) {
			super.mouseDown(with: event)
			updateCursor    (for: event)
		}
	}

	override func mouseMoved(with event: ZEvent) {
		super.mouseMoved(with: event)
		updateCursor(for: event)
	}

	// change cursor to
	// indicate action possible on what's under cursor
	// and possibly display a tool tip

	func updateCursor(for event: ZEvent) {
		let rect = rectFromEvent(event)

		if  linkHit(at: rect) {
			NSCursor.arrow.set()
		} else if let   dot = dragDotHit(at: rect) {
			if  let    note = dot.note {
				let grabbed = grabbedNotes.contains(note)
				toolTip     = note.tooltipString(grabbed: grabbed)
			}

			NSCursor.arrow.set()
		} else if let attach = hitTestForAttachment(in: rect) {
			if  let      dot = hitTestForResizeDot(in: rect, for: attach) {
				dot.cursor.set()
			} else {
				NSCursor.openHand.set()
			}
		} else {
			toolTip = nil

			NSCursor.iBeam.set()
		}

		setNeedsDisplay()
	}

	override func setSelectedRange(_ range: NSRange) {
		if  let         text = textStorage?.string {
			let storageRange = NSRange(location: 0, length: text.length)
			let     endRange = NSRange(location: text.length, length: 0)
			let       common = range.intersection(storageRange) ?? endRange

			super.setSelectedRange(common)

			if  let               rect  = rectForRange(common),
				selectedRange.location != 0 {
				selectionRect           = rect
			}
		}
	}

	private func selectAndScrollTo(_ range: NSRange? = nil) {
		var        point = CGPoint()                          // scroll to top
		if  let    essay = gCurrentEssay,
			(essay.lastTextIsDefault || range != nil),
			let range    = range ?? essay.lastTextRange {     // default: select entire text of final essay

			if  let rect = rectForRange(range) {
				point    = rect.origin
				point .y = max(0.0, point.y - 100.0)
			}

			setSelectedRange(range)
		}

		scroll(point)
	}

	func asssureSelectionIsVisible() {
		for note in selectedNotes {
			if  let zone = note.zone {
				zone.asssureIsVisible()
			}
		}
	}

	func scrollToGrabbed() {
		if  let range = lastGrabbedDot?.noteRange {
			scrollRangeToVisible(range)
		}
	}

	// MARK: - setup
	// MARK: -

	override func awakeFromNib() {
		super.awakeFromNib()

		usesRuler            = true
		isRulerVisible       = true
		importsGraphics      = true
		usesInspectorBar     = true
		allowsImageEditing   = true
		displaysLinkToolTips = true
		textContainerInset   = NSSize(width: margin, height: margin)

		resetForDarkMode()

		FOREGROUND { // wait for application to fully load the inspector bar
			gMainWindow?.updateEssayEditorInspectorBar(show: false)

			for tag in ZEssayButtonID.all {
				self.addButtonFor(tag)
			}

			self.addTitlesControl()
		}
	}

	private func discardPriorText() {
		gCurrentEssayZone?.noteMaybe = nil
		delegate                     = nil		// clear so that shouldChangeTextIn won't be invoked on insertText or replaceCharacters

		if  let length = textStorage?.length, length > 0 {
			textStorage?.replaceCharacters(in: NSRange(location: 0, length: length), with: kEmpty)
		}
	}

	func resetForDarkMode() {
		usesAdaptiveColorMappingForDarkAppearance = true
		let                       backgroundColor = (gIsDark ?  kDarkestGrayColor : kWhiteColor).cgColor
		let                            scrollView = superview?.superview as? NSScrollView
		let                             rulerView = scrollView?.horizontalRulerView
		let                              scroller = scrollView?.verticalScroller
		let modeAppearance                        = NSAppearance(named: gIsDark ? .darkAqua : .aqua)
		appearance                                = modeAppearance
		rulerView?                    .appearance = modeAppearance
		scroller?                     .appearance = modeAppearance
		scroller?.zlayer         .backgroundColor = backgroundColor
		zlayer                   .backgroundColor = backgroundColor
	}

	func setup() {
		updateTextStorage()
	}

	@discardableResult func resetCurrentEssay(_ current: ZNote? = gCurrentEssay, selecting range: NSRange? = nil) -> Int {
		var           delta = 0
		if  let        note = current {
			essayRecordName = nil
			gCurrentEssay   = note

			note.setupChildren()

			delta           = updateTextStorage()

			note.updateNoteOffsets()
			note.updatedRangesFrom(note.noteTrait?.noteText)

			if  let r = range {
				FOREGROUND {
					self.selectAndScrollTo(r.offsetBy(delta))
				}
			}
		}

		return delta
	}

	@discardableResult func updateTextStorage(restoreSelection: NSRange? = nil) -> Int {
		var delta = 0

		// make sure we actually have a current essay
		// activate the buttons in the control bar
		// grab the current essay text and put it in place
		// grab record id of essay to indicate that essay
		// has not been saved, avoids overwriting later

		resetForDarkMode()

		if  gCurrentEssay == nil {
			gControllers.swapMapAndEssay(force: .wMapMode)                    // not show blank essay
		} else {
			updateTitleSegments()

			delta = updateTitlesControlAndMode()

			if  (shouldOverwrite || restoreSelection != nil),
				let text = gCurrentEssay?.essayText {
				discardPriorText()
				gCurrentEssay?.noteTrait?.whileSelfIsCurrentTrait { setText(text) }   // inject text
				selectAndScrollTo(restoreSelection)
				undoManager?.removeAllActions()                               // clear the undo stack of prior / disastrous information (about prior text)
				matchTitlesControlTo(gEssayTitleMode)
			}

			enableEssayControls(true)

			essayRecordName = gCurrentEssayZone?.recordName                   // do this after overwriting
			delegate        = self 					    	                  // set delegate after setText

			if  gIsEssayMode {
				gMainWindow?.makeFirstResponder(self)                         // show cursor and respond to key input
			}
		}

		return delta
	}

	// MARK: - clean up
	// MARK: -

	func done() {
		save()
		exit()
	}

	func exit() {
		prepareToExit()
		gControllers.swapMapAndEssay(force: .wMapMode)
	}

	func save() {
		if  let e = gCurrentEssay {
			e.saveInEssay(textStorage)
		}
	}

	func prepareToExit() {
		if  let e = gCurrentEssay,
			e.lastTextIsDefault,
			e.autoDelete {
			e.zone?.deleteNote()
		}

		undoManager?.removeAllActions()
	}

	func grabSelectionHereDone() {
		if  let zone = selectedZone {
			gHere = zone

			zone.grab()
			done()
		} else {
			grabDone()
		}
	}

	func grabDone() {
		if  let zone = lastGrabbedDot?.note?.zone {
			zone.grab()
		} else {
			gCurrentEssayZone?.grab()
		}

		done()
	}

	// MARK: - locked ranges
	// MARK: -

	func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRange oldSelectedCharRange: NSRange, toCharacterRange newSelectedCharRange: NSRange) -> NSRange {
		let     noKeys = gCurrentKeyPressed == nil
		let     locked = gCurrentEssay?.isLocked(within: newSelectedCharRange) ?? false
		return (locked && noKeys) ? oldSelectedCharRange : newSelectedCharRange
	}

	func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString replacement: String?) -> Bool {
		setNeedsDisplay()        // so dots selecting image will be redrawn

		if  let replacementLength = replacement?.length,
			let (result,   delta) = gCurrentEssay?.shouldAlterEssay(in: range, replacementLength: replacementLength) {
			switch result {
				case .eAlter:         break
				case .eLock:          return false
				case .eExit:  exit(); return false
				case .eDelete:
					FOREGROUND {                          // DEFER UNTIL AFTER THIS METHOD RETURNS ... avoids corrupting resulting text
						gCurrentEssay?.setupChildren()
						self.updateTextStorage(restoreSelection: NSRange(location: delta, length: range.length))		// recreate essay text and restore cursor position within it
					}
			}

			gCurrentEssay?.essayLength += delta           // compensate for change
		}

		return true // yes, change text
	}

	// MARK: - grab / drag
	// MARK: -

	func handleGrabbed(_ arrow: ZArrowKey, flags: ZEventFlags) {

		// SHIFT single note expand to essay and vice-versa

		let indents = relativeLevelOfFirstGrabbed

		if  flags.isOption {
			if (arrow == .left && indents > 1) || ([.up, .down, .right].contains(arrow) && indents > 0) {
				save()

				gMapEditor.handleArrow(arrow, flags: flags) {
					self.resetTextAndGrabs()
				}
			}
		} else if flags.isShift {
			if [.left, .right].contains(arrow) {
				// conceal reveal subnotes of grabbed (NEEDS new ZEssay code)
			}
		} else if arrow == .left {
			if  indents == 0 {
				done()
			} else {
				swapBetweenNoteAndEssay()
			}
		} else if [.up, .down].contains(arrow) {
			grabNextNote(up: arrow == .up, ungrab: !flags.isShift)
			scrollToGrabbed()
			gSignal([.sDetails])
		}
	}

	func grabbedIndex(goingUp: Bool) -> Int? {
		let dots = goingUp ? dragDots : dragDots.reversed()
		let  max = dots.count - 1

		for (index, dot) in dots.enumerated() {
			if  let zone = dot.note?.zone,
				grabbedZones.contains(zone) {
				return goingUp ? index : max - index
			}
		}

		return nil
	}

	var lastGrabbedDot : ZEssayDragDot? {
		var grabbed : ZEssayDragDot?

		for dot in dragDots {
			if  let zone = dot.note?.zone,
				grabbedZones.contains(zone) {
				grabbed = dot
			}
		}

		return grabbed
	}

	var dragDots:  [ZEssayDragDot] {
		var dots = [ZEssayDragDot]()

		if  let essay = gCurrentEssay, !essay.isNote,
			let  zone = essay.zone,
			let     l = layoutManager,
			let     c = textContainer {
			let zones = zone.zonesWithNotes
			let level = zone.level
			for (index, zone) in zones.enumerated() {
				if  var note   = zone.note {
					if  index == 0 { //,           // huh?
						note   = essay
					}

					let dragHeight = 15.0
					let  dragWidth = 11.75
					let      color = zone.color ?? kDefaultIdeaColor
					let     offset = index == 0 ? 0 : (index != zones.count - 1) ? 1 : 2     // first and last note have altered offset (thus, altered range)
					let  noteRange = note.noteRange.offsetBy(offset)
					let      inset = CGFloat(2.0)
					let   noteRect = l.boundingRect(forGlyphRange: noteRange, in: c).offsetBy(dx: 18.0, dy: margin + inset + 1.0).expandedEquallyBy(inset)
					let     indent = zone.level - level
					let     noLine = indent == 0
					let lineOrigin = noteRect.origin.offsetBy(CGPoint(x: 3.0, y: dragHeight))
					let  lineWidth = dragWidth * Double(indent)
					let   lineSize = CGSize(width: lineWidth, height: 0.5)
					let   lineRect = noLine ? nil : CGRect(origin: lineOrigin, size: lineSize)
					let dragOrigin = lineOrigin.offsetBy(CGPoint(x: lineWidth, y: -8.0))
					let   dragSize = CGSize(width: dragWidth, height: dragHeight)
					let   dragRect = CGRect(origin: dragOrigin, size: dragSize)

					dots.append(ZEssayDragDot(color: color, dragRect: dragRect, textRect: noteRect, lineRect: lineRect, noteRange: noteRange, note: note))
				}
			}
		}

		return dots
	}

	func drawDragDecorations() {
		for (index, dot) in dragDots.enumerated() {
			if  let     zone = dot.note?.zone {
				let  grabbed = grabbedZones.contains(zone)
				let extendBy = index == 0 ? kNoteIndentSpacer.length : -1        // fixes intersection computation, first and last note have altered range
				let selected = dot.noteRange?.extendedBy(extendBy).inclusiveIntersection(selectedRange) != nil
				let   filled = selected && !hasGrabbedNote
				let    color = dot.color

				dot.dragRect.drawColoredOval(color, filled: filled || grabbed)

				if  let lineRect = dot.lineRect {
					drawColoredRect(lineRect, color, thickness: 0.5)
				}

				if  grabbed {
					drawColoredRect(dot.textRect, color)
				}
			}
		}
	}

	func dragDotHit(at rect: CGRect) -> ZEssayDragDot? {
		for dot in dragDots {
			if  dot.dragRect.intersects(rect) {
				return dot
			}
		}

		return nil
	}

	func grabSelected() {
		let  hadNoGrabs = !hasGrabbedNote

		ungrabAll()

		if  hadNoGrabs,
			gCurrentEssay?.children.count ?? 0 > 1 {     // ignore if does not have multiple children

			for note in selectedNotes {
				grabbedNotes.appendUnique(item: note)
			}

			scrollToGrabbed()
			gSignal([.sDetails])
		}

		setNeedsDisplay()
	}

	func grabNextNote(up: Bool, ungrab: Bool) {
		let      dots = dragDots
		if  let index = grabbedIndex(goingUp: up),
			let   dot = dots.next(from: index, forward: up),
			let  note = dot.note {

			if  ungrab {
				ungrabAll()
			}

			grabbedNotes.append(note)
			scrollToGrabbed()
		}
	}

	func swapWithParent() {
		if !firstIsGrabbed,
		    let note = firstGrabbedNote,
			let zone = note.zone {
			save()
			gCurrentEssayZone?.clearAllNotes()            // discard current essay text and all child note's text
			ungrabAll()

			gNeedsRecount = true
			let    parent = zone.parentZone                  // get the parent before we swap
			let     reset = parent == self.firstNote?.zone   // check if current esssay should change

			gDisablePush {
				zone.swapWithParent {
					if  reset {
						gCurrentEssay = ZEssay(zone)
					}

					self.resetTextAndGrabs(grab: parent)
				}
			}
		}
	}

	@discardableResult func deleteGrabbed() -> Bool {
		if  hasGrabbedNote {
			for zone in grabbedZones {
				zone.deleteNote()
			}

			ungrabAll()
			resetTextAndGrabs()

			return true
		}

		return false
	}

	func ungrabAll() { grabbedNotes.removeAll() }

	func regrab(_ ungrabbed: ZoneArray) {
		for zone in ungrabbed {                         // re-grab notes for set aside zones
			if  let note = zone.note {                // note may not be same
				grabbedNotes.appendUnique(item: note)
			}
		}
	}

	func willRegrab(_ grab: Zone? = nil) -> ZoneArray {
		var           grabbed = ZoneArray()

		grabbed.append(contentsOf: grabbedZones)      // copy current grab's zones aside
		ungrabAll()

		if  let          zone = grab {
			grabbed           = [zone]

			if  zone         == gCurrentEssay?.zone,
				let     first = firstGrabbedZone {
				gCurrentEssay = ZEssay(first)
			}
		}

		return grabbed
	}

	func resetTextAndGrabs(grab: Zone? = nil) {
		let     grabbed = willRegrab(grab)              // includes logic for optional grab parameter
		essayRecordName = nil                           // so shouldOverwrite will return true

		gCurrentEssayZone?.clearAllNotes()            // discard current essay text and all child note's text
		updateTextStorage()                                  // assume text has been altered: re-assemble it
		regrab(grabbed)
		scrollToGrabbed()
		gSignal([.spCrumbs, .sDetails])
	}

	// MARK: - buttons
	// MARK: -

	func enableEssayControls(_      enabled: Bool) {
		let      hasMultipleNotes = gCurrentSmallMapRecords?.workingNotemarks.count ?? 0 > 1
		backwardButton?.isEnabled = enabled && hasMultipleNotes
		forwardButton? .isEnabled = enabled && hasMultipleNotes
		titlesControl? .isEnabled = enabled
		deleteButton?  .isEnabled = enabled
		cancelButton?  .isEnabled = enabled
		hideButton?    .isEnabled = enabled
		saveButton?    .isEnabled = enabled

		updateTitleSegments(enabled)
		redrawInspectorBar (enabled)
	}

	func redrawInspectorBar(_ enabled: Bool) {
		if  let      bar = gMainWindow?.inspectorBar {
			bar.isHidden = !enabled

			bar.draw(bar.bounds)
		}
	}

	@objc private func handleButtonPress(_ iButton: ZButton) {
		if  let buttonID = ZEssayButtonID(rawValue: iButton.tag) {
			switch buttonID {
				case .idForward: save(); gCurrentSmallMapRecords?.go(down:  true, amongNotes: true) { gRelayoutMaps() }
				case .idBack:    save(); gCurrentSmallMapRecords?.go(down: false, amongNotes: true) { gRelayoutMaps() }
				case .idSave:    save()
				case .idHide:                          grabDone()
				case .idCancel:                        gCurrentEssayZone?.grab();       exit()
				case .idDelete:  if !deleteGrabbed() { gCurrentEssayZone?.deleteNote(); done() }
				default:         break
			}
		}
	}

	private func controlRect(at target: Int) -> CGRect? {
		var rect : CGRect?
		if  let   inspectorBar = gMainWindow?.inspectorBar {

			// ////////////////////////////////////////////////// //
			// Apple bug: subviews are not located where expected //
			// ////////////////////////////////////////////////// //

			rect                = inspectorBar.subviews[0].frame
			var prior           = rect!

			for index in 1...target {
				let tool        = inspectorBar.subviews[index]
				tool.isHidden   = false
				rect?.size      = tool.size
				rect?.origin.x += prior.size.width + 4.0
				rect?.origin.y  = -2.0
				prior           = rect!
			}

			rect?.origin.x     += 23.0
		}

		return rect
	}

	private func addButtonFor(_ tag: ZEssayButtonID) {
		if  let inspectorBar = gMainWindow?.inspectorBar {

			func buttonWith(_ title: String) -> ZTooltipButton {
				let    action = #selector(handleButtonPress)

				if  let image = ZImage(named: title)?.resize(CGSize.squared(14.0)) {
					return      ZTooltipButton(image: image, target: self, action: action)
				}

				let    button = ZTooltipButton(title: title, target: self, action: action)
				button  .font = gTinyFont

				return button
			}

			func buttonFor(_ tag: ZEssayButtonID) -> ZTooltipButton? {
				if  var         frame = controlRect(at: inspectorBar.subviews.count - 1) {
					let         title = tag.title
					let        button = buttonWith(title)
					frame       .size = button.size
					frame             = frame.insetBy(dx: 12.0, dy: 6.0)
					button       .tag = tag.rawValue
					button     .frame = frame
					button .isEnabled = false
					button.isBordered = true
					button.bezelStyle = .texturedRounded

					button.setButtonType(.momentaryChange)
					button.updateTracking()

					return button
				}

				return nil
			}

			func assignButton(_ button: ZButton) {
				if  let    tag = ZEssayButtonID(rawValue: button.tag) {
					switch tag {
						case .idBack:   backwardButton = button
						case .idForward: forwardButton = button
						case .idCancel:   cancelButton = button
						case .idDelete:   deleteButton = button
						case .idHide:       hideButton = button
						case .idSave:       saveButton = button
						default: break
					}
				}
			}

			if  let b = buttonFor(tag) {
				inspectorBar.addSubview(b)
				assignButton(b)
			}
		}
	}

	// MARK: - titles control
	// MARK: -

	func addTitlesControl() {
		if  let  inspectorBar = gMainWindow?.inspectorBar,
			let       control = titlesControl,
			var         frame = controlRect(at: inspectorBar.subviews.count - 1) {
			frame       .size = control.size
			control    .frame = frame.offsetBy(dx: 14.0, dy: 6.0)
			control.isEnabled = false


			inspectorBar.addSubview(control)
		}
	}

	func updateTitleSegments(_ enabled: Bool = true) {
		let                  isNote = (gCurrentEssay?.children.count ?? 0) == 0
		titlesControl?.segmentCount = isNote ? 2 : 3
		titlesControl?   .isEnabled = enabled

		if !isNote {
			let image = ZImage(named: "show.drag.dot")?.resize(CGSize.squared(16.0))
			titlesControl?.setToolTip("show all titles", forSegment: 2)
			titlesControl?.setImage(image,               forSegment: 2)
		}
	}

	func matchTitlesControlTo(_ mode: ZEssayTitleMode) {
		let    last = (titlesControl?.segmentCount ?? 1) - 1
		let segment = min(last, mode.rawValue)

		titlesControl?.selectedSegment = segment
	}

	@discardableResult func updateTitlesControlAndMode() -> Int {
		let mode = gAdjustedEssayTitleMode

		matchTitlesControlTo(mode)

		return deltaForTransitioningTo(mode)  // updates gEssayTitleMode
	}

	@IBAction func handleSegmentedControlAction(_ iControl: ZSegmentedControl) {
		if  let  mode = ZEssayTitleMode(rawValue: iControl.selectedSegment) {
			var range = selectedRange

			save()

			range.location += deltaForTransitioningTo(mode)
			titlesControl?.needsDisplay = true

			updateTextStorage(restoreSelection: range)
			gSignal([.sEssay])
		}
	}

	func titleLengthsUpTo(_ note: ZNote, for mode: ZEssayTitleMode) -> Int {
		let    isEmpty = mode == .sEmpty
		let     isFull = mode == .sFull
		if  let  eZone = gCurrentEssay?.zone,  // essay zones
			let target = note.zone {           // target zone
			let eZones = eZone.zonesWithNotes
			let  isOne = eZones.count == 1
			var  total = isOne ? -4 : isEmpty ? -2 : isFull ? -2 : 0

			for zone in eZones {
				if  let zNote = zone.note {
					zNote.updateIndentCount(relativeTo: eZone)

					total += zNote.titleOffsetFor(mode)
				}

				if  zone  == target {
					return total
				}
			}
		}

		return isEmpty ? 0 : note.titleRange.length
	}

	func deltaForTransitioningTo(_ mode: ZEssayTitleMode) -> Int {
		var delta           = 0
		if  mode           != gEssayTitleMode {
			if  let    note = selectedNote {
				let  before = titleLengthsUpTo(note, for: gEssayTitleMode) // call this first
				let   after = titleLengthsUpTo(note, for: mode)            // call this second
				delta       = after - before
			}

			gEssayTitleMode = mode
		}

		return delta
	}

	// MARK: - images
	// MARK: -

	func clearImageResizeRubberband() {
		if  resizeDragRect == nil {
			let        path = ZBezierPath(rect: bounds)

			kClearColor.setFill()
			path.fill() // erase rubberband
		}
	}

	func drawImageResizeDots(around attach: ZRangedAttachment?) {
		if  let       rect = resizeDragRect {
			let       path = ZBezierPath(rect: rect)
			let    pattern : [CGFloat] = [4.0, 4.0]
			path.lineWidth = CGFloat(gLineThickness * 3.0)
			path.flatness  = 0.0001

			path.setLineDash(pattern, count: 2, phase: 4.0)
			path.stroke()
			drawImageResizeDots(onBorderOf: rect)
		} else if let    a = attach,
				  let rect = rectForRangedAttachment(a) {
			drawImageResizeDots(onBorderOf: rect)
		}
	}

	func drawImageResizeDots(onBorderOf rect: CGRect) {
		for point in rect.selectionPoints.values {
			let   dotRect = CGRect(origin: point, size: .zero).insetEquallyBy(dotInset)
			let      path = ZBezierPath(ovalIn: dotRect)
			path.flatness = 0.0001

			path.stroke()
		}
	}

	override func draggingEntered(_ drag: NSDraggingInfo) -> NSDragOperation {
		if  let    board = drag.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
			let     path = board[0] as? String {
			let fileName = URL(fileURLWithPath: path).lastPathComponent
			printDebug(.dImages, "DROP     \(fileName)")
			dropped.append(fileName)
		}

		return .copy
	}

	func clearResizing() {
		eraseAttachment = nil
		imageAttachment = nil
		resizeDragStart = nil
		resizeDragRect  = nil
		resizeDot       = nil
	}

	override func mouseDragged(with event: ZEvent) {
		super.mouseDragged(with: event)

		if  resizeDot    != nil,
			let     start = resizeDragStart {
			let     flags = event.modifierFlags
			let sizeDelta = CGSize(rectFromEvent(event).origin - start)

			updateImageRubberband(for: sizeDelta, flags.isCommand)
			setNeedsDisplay()
		}
	}

	func updateImageRubberband(for delta: CGSize, _ COMMAND : Bool) {

		// compute imageDragRect from delta.width, image rect and corner
		// preserving aspect ratio

		if  let direction = resizeDot,
			let    attach = imageAttachment,
			let      rect = rectForUnclippedRangedAttachment(attach, orientedFrom: direction) {
			var      size = rect.size
			var    origin = rect.origin
			var  fraction = size.fraction(delta)

			if  COMMAND, [ZDirection.topLeft, ZDirection.bottomRight].contains(direction) { // apply original ratio to fraction
				fraction  = size.fractionPreservingRatio(delta)
			}

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

	override func mouseUp(with event: ZEvent) {
		super.mouseUp(with: event)

		if  resizeDot != nil,
			updateImage(),
			let attach = imageAttachment {
			let  range = attach.range

			save()
			asssureSelectionIsVisible()
			clearResizing()
			setNeedsLayout()
			setNeedsDisplay()
			updateTextStorage(restoreSelection: range)  // recreate essay after an image is dropped
		}
	}

	func updateImage() -> Bool {
		if  let         size  = resizeDragRect?.size,
			let            a  = imageAttachment?.attachment,
			let         wrap  = a.fileWrapper,
			let        image  = a.cellImage {
			let      oldSize  = image.size
			if       oldSize != size,
				let newImage  = image.resizedTo(size) {
				a .cellImage  = newImage

				if  gFiles.writeImage(newImage, using: wrap.preferredFilename) != nil {
					return true
				}
			}
		}

		return false
	}

	func hitTestForResizeDot(in selectionRect: CGRect, for attachment: ZRangedAttachment?) -> ZDirection? {
		if  let    attach = attachment,
			let imageRect = rectForRangedAttachment(attach) {
			let    points = imageRect.selectionPoints

			for (direction, point) in points {
				var  rect = CGRect(origin: point, size: .zero).insetEquallyBy(dotInset)
				let  size = imageRect.size.multiplyBy(-0.5).insetBy(dotInset, dotInset)

				switch direction {
					case .bottom, .top: rect = rect.insetBy(dx: size.width, dy: 0.0)  // extend width
					case .right, .left: rect = rect.insetBy(dx: 0.0, dy: size.height) // extend height
					default:            break
				}

				if  selectionRect.intersects(rect) {
					return direction
				}
			}
		}

		return nil
	}

	func rectForUnclippedRangedAttachment(_ attach: ZRangedAttachment, orientedFrom direction: ZDirection) -> CGRect? {      // return nil if image is clipped
		if  let image       = attach.attachment.cellImage,
			var rect        = rectForRangedAttachment(attach) {
			if  rect.size.absoluteDifferenceInDiagonals(relativeTo: image.size) > 2.0 {
				let  yDelta = image.size.height - rect.height
				rect  .size = image.size
				switch direction {
					case .topRight,
						 .topLeft,
						 .top: rect.origin.y -= yDelta
					default:   break
				}
			}

			return rect
		}

		return nil
	}

	func rectForRangedAttachment(_ attach: ZRangedAttachment) -> CGRect? {
		if  let    rect = attach.glyphRect(for: textStorage, margin: margin) {
			return rect
		}

		return nil
	}

	func hitTestForAttachment(in rect: CGRect) -> ZRangedAttachment? {
		if  let attaches = textStorage?.rangedAttachments {
			for attach in attaches {
				if  let imageRect = rectForRangedAttachment(attach)?.insetEquallyBy(dotInset),
					imageRect.intersects(rect) {

					return attach
				}
			}
		}

		return nil
	}

	// MARK: - search
	// MARK: -

	func grabSelectedTextForSearch() {
		gSearching.essaySearchText = selectionString
	}

	func performSearch(for searchString: String) {
		gSearching.essaySearchText = searchString

		searchAgain(false)
	}

	func searchAgain(_ OPTION: Bool) {
	    let    seek = gSearching.essaySearchText
		var  offset = selectedRange.upperBound + 1
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
			scrollToVisible(selectionRect)
			setSelectedRange(matches![0].offsetBy(offset))
		}
	}

	// MARK: - special characters
	// MARK: -

	private func showSpecialCharactersPopup() {
		let  menu = ZMenu.specialCharactersPopup(target: self, action: #selector(handleSymbolsPopupMenu(_:)))
		let point = selectionRect.origin.offsetBy(-165.0, -60.0)

		menu.popUp(positioning: nil, at: point, in: self)
	}

	@objc private func handleSymbolsPopupMenu(_ iItem: ZMenuItem) {
		if  let type = ZSpecialCharactersMenuType(rawValue: iItem.keyEquivalent),
			type    != .eCancel {
			let text = type.text

			insertText(text, replacementRange: selectedRange)
		}
	}

	// MARK: - hyperlinks
	// MARK: -

	var currentLink: Any? {
		var found: Any?
		var range = selectedRange

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

	private func showLinkPopup() {
		let menu = ZMenu(title: "create a link")
		menu.autoenablesItems = false

		for type in ZEssayLinkType.all {
			menu.addItem(item(type: type))
		}

		menu.popUp(positioning: nil, at: selectionRect.origin, in: self)
	}

	private func item(type: ZEssayLinkType) -> ZMenuItem {
		let  	  item = ZMenuItem(title: type.title, action: #selector(handleLinkPopupMenu(_:)), keyEquivalent: type.rawValue)
		item   .target = self
		item.isEnabled = true

		item.keyEquivalentModifierMask = ZEvent.ModifierFlags(rawValue: 0)

		return item
	}

	@objc private func handleLinkPopupMenu(_ iItem: ZMenuItem) {
		if  let   type = ZEssayLinkType(rawValue: iItem.keyEquivalent) {
			let  range = selectedRange
			let showAs = textStorage?.string.substring(with: range)
			var   link : String? = type.linkType + kColonSeparator

			func setLink(to appendToLink: String?, replacement: String? = nil) {
				if  let a = appendToLink, !a.isEmpty {
					link?.append(a)
				} else {
					link  = nil  // remove existing hyperlink
				}

				if  link == nil {
					textStorage?.removeAttribute(.link,               range: range)
				} else {
					textStorage?   .addAttribute(.link, value: link!, range: range)
				}

				if  let r = replacement {
					textStorage?.replaceCharacters(in: range, with: r)
				}

				selectAndScrollTo(range)
			}

			func displayUploadDialog() {
				ZFiles.presentOpenPanel() { (iAny) in
					if  let      url = iAny as? URL {
						let    asset = CKAsset(fileURL: url)
						if  let file = ZFile.uniqueFile(asset, databaseID: gDatabaseID),
							let name = file.recordName {

							setLink(to: name, replacement: showAs)
						}
					} else if let panel = iAny as? NSPanel {
						panel.title = "Import"
					}
				}
			}

			func displayLinkDialog() {
				gEssayController?.modalForLink(type: type, showAs) { path, replacement in
					setLink(to: path, replacement: replacement)
				}
			}

			switch type {
				case .hEmail,
					 .hWeb:   displayLinkDialog()
				case .hFile:  displayUploadDialog()
				case .hClear: setLink(to: nil)
				default:      setLink(to: gSelecting.pastableRecordName)
			}
		}
	}

	func followLinkInSelection() -> Bool {
		if  let  link = currentLink as? String {
			let parts = link.components(separatedBy: kColonSeparator)

			if  parts.count > 1,
				let     one = parts.first?.first,                          // first character of first part
				let    name = parts.last,
				let    type = ZEssayLinkType(rawValue: String(one)) {
				let zRecord = gRemoteStorage.maybeZRecordForRecordName(name)  // find zone whose record name == name
				switch type {
					case .hEmail:
						link.openAsURL()
						return true
					case .hFile:
						gFilesRegistry.fileWith(name, in: gDatabaseID)?.activate()

						return true
					case .hIdea:
						if  let  grab = zRecord as? Zone {
							let eZone = gCurrentEssayZone

							FOREGROUND {
								self  .done()                           // changes grabs and here, so ...

								gHere = grab			                // focus on zone

								grab  .grab()                           // select it, too
								grab  .asssureIsVisible()
								eZone?.asssureIsVisible()
								gRelayoutMaps()
							}

							return true
						}
					case .hEssay, .hNote:
						if  let target = zRecord as? Zone {

							save()

							let common = gCurrentEssayZone?.closestCommonParent(of: target)

							FOREGROUND {
								if  let  note = target.noteMaybe, gCurrentEssay?.children.contains(note) ?? false {
									let range = note.offsetTextRange	    // text range of target essay
									let start = NSRange(location: range.location, length: 1)

									self.setSelectedRange(range)

									if  let    r = self.rectForRange(start) {
										let rect = self.convert(r, to: self).offsetBy(dx: 0.0, dy: -150.0)

										// highlight text of note, and scroll it to visible

										self.scroll(rect.origin)
									}
								} else {
									gCreateCombinedEssay = type == .hEssay

									target .asssureIsVisible()		        // for later, when user exits essay mode
									common?.asssureIsVisible()
									self.resetCurrentEssay(target.note)     // change current note to that of target
									gSignal([.spSmallMap, .spCrumbs])
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
		setSelectedRange(NSRange(location: charIndex, length: 0))

		return followLinkInSelection()
	}

	// MARK: - more
	// MARK: -

	func swapBetweenNoteAndEssay() {
		if  let current = gCurrentEssay,
			let    zone = current.zone {
			let   count = current.children.count
			let toEssay = count < 2
			let   range = selectedRange

			current.updatedRangesFrom(textStorage)
			save()

			gCreateCombinedEssay = toEssay // toggle

			if  toEssay {
				gCurrentEssay = ZEssay(zone)

				zone.clearAllNotes()            // discard current essay text and all child note's text
				resetCurrentEssay(selecting: range)
			} else if var note = lastGrabbedDot?.note ?? selectedNote {
				ungrabAll()

				if !note.isNote {
					note = ZNote(note.zone)
				}

				resetCurrentEssay(note, selecting: range)
			}

			gSignal([.sDetails])
		}
	}

	func popNoteAndUpdate() {
		if  gRecents.pop(),
			let  notemark = gRecents.rootZone?.notemarks.first,
			let      note = notemark.bookmarkTarget?.note {
			gCurrentEssay = note

			gRecents.setAsCurrent(notemark)
			gSignal([.spSmallMap, .spCrumbs])

			updateTextStorage()
		}
	}

	func move(out: Bool) {
		gCreateCombinedEssay = true
		let            range = selectedRange()
		let             note = gCurrentEssay?.noteIn(range)
		let            prior = (note?.noteOffset ?? 0) + (note?.indentCount ?? 0)

		save()

		if  out {
			gCurrentEssayZone?.traverseAncestors { ancestor -> (ZTraverseStatus) in
				if  ancestor != gCurrentEssayZone, ancestor.hasNote,
					let essay = ancestor.note {
					let delta = self.resetCurrentEssay(essay)

					if  let zone = note?.zone {
						for within in essay.children {
							if  zone == within.zone {
								let offset = within.noteOffset
								let indent = within.indentCount
								let select = range.offsetBy(offset + delta + indent - prior + 1)

								self.selectAndScrollTo(select)
							}
						}
					}

					return .eStop
				}

				return .eContinue
			}
		} else if let n = note, n != gCurrentEssay { // go in/right
			let  offset = n.noteOffset
			let  indent = n.indentCount
			let  adjust = indent * (n.isNote ? 1 : 2) + ((indent < 3) ? 0 : indent - 2)
			let   delta = self.resetCurrentEssay(n)
			let  select = range.offsetBy(delta - offset - adjust + 1)

			self.selectAndScrollTo(select)
		}

		gSignal([.spCrumbs])
	}

	private func convertToChild(_ flags: ZEventFlags) {
		if  let   text = selectionString, text.length > 0,
			let   dbID = gCurrentEssayZone?.databaseID,
			let parent = selectedZone {

			func child(named name: String, withText: String) {
				let child = Zone.uniqueZoneNamed(name, databaseID: dbID)   	// create new (to be child) zone from text

				parent.addChildNoDuplicate(child)
				child.setTraitText(text, for: .tNote)                       // create note from text in the child
				gCurrentEssayZone?.createNote()

				resetCurrentEssay(gCurrentEssayZone?.note, selecting: child.noteMaybe?.offsetTextRange)	// redraw essay TODO: WITH NEW NOTE SELECTED
			}

			if        flags.exactlyUnusual {
				child(named: "idea", withText: text)
			} else if flags.isOption {
				child(named: text,   withText: kEmpty)
			} else {
				let child = Zone.uniqueZoneNamed(text, databaseID: dbID)   	// create new (to be child) zone from text
				insertText(kEmpty, replacementRange: selectedRange)	            // remove text
				parent.addChildNoDuplicate(child)
				child.asssureIsVisible()
				save()

				child.grab()
				done()

				FOREGROUND {                                            // defer idea edit until after this function exits
					child.edit()
				}
			}
		}
	}

	private func alterCase(up: Bool) {
		if  let        text = selectionString {
			let replacement = up ? text.uppercased() : text.lowercased()

			insertText(replacement, replacementRange: selectedRange)
		}
	}

	func applyToSelection(BOLD: Bool = false, ITALICS: Bool = false) {
		if  let dict = textStorage?.fontAttributes(in: selectedRange),
			let font = dict[.font] as? ZFont {
			var desc = font.fontDescriptor
			var traz = desc.symbolicTraits

			if  BOLD {
				if  traz.contains(.bold) {
					traz  .remove(.bold)
				} else {
					traz  .insert(.bold)
				}
			}

			if  ITALICS {
				if  traz.contains(.italic) {
					traz  .remove(.italic)
				} else {
					traz  .insert(.italic)
				}
			}

			desc = desc.withSymbolicTraits(traz)
			let bold = ZFont(descriptor: desc, size: font.pointSize) as Any

			textStorage?.setAttributes([.font : bold], range: selectedRange)
		}
	}

}

