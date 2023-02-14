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

@objc (ZEssayView)
class ZEssayView: ZTextView, ZTextViewDelegate, ZSearcher {
	let margin             = CGFloat(20.0)
	var dropped            = StringsArray()
	var visibilities       = ZNoteVisibilityArray()
	var grabbedNotes       = ZNoteArray()
	var selectionRect      = CGRect()  { didSet { if selectionRect.origin == .zero { selectedAttachment = nil } } }
	var grabbedZones       : ZoneArray { return grabbedNotes.map { $0.zone! } }
	var firstNote          : ZNote?    { return (dragDots.count == 0) ? nil : dragDots[0].note }
	var firstGrabbedNote   : ZNote?    { return hasGrabbedNote ? grabbedNotes[0] : nil }
	var firstGrabbedZone   : Zone?     { return firstGrabbedNote?.zone }
	var selectedNote       : ZNote?    { return selectedNotes.last ?? gCurrentEssay }
	var selectedZone       : Zone?     { return selectedNote?.zone }
	var hasGrabbedNote     : Bool      { return grabbedNotes.count != 0 }
	var lockedSelection    : Bool      { return gCurrentEssay?.isLocked(within: selectedRange) ?? false }
	var firstIsGrabbed     : Bool      { return hasGrabbedNote && firstGrabbedZone == firstNote?.zone }
	var selectionString    : String?   { return textStorage?.attributedSubstring(from: selectedRange).string }
	var essayRecordName    : String?
	var resizeDragStart    : CGPoint?
	var resizeDragRect     : CGRect?
	var resizeDot          : ZDirection?
	var selectedAttachment : ZRangedAttachment?

	var selectedNotes : ZNoteArray {
		gCurrentEssay?.updateNoteOffsets()

		return (gCurrentEssay?.zone?.zonesWithVisibleNotes.filter {
			guard let range = $0.note?.noteRange else { return false }
			return selectedRange.intersects(range.extendedBy(1))
		}.map {
			$0.note!
		})!
	}

	var shouldOverwrite: Bool {
		if  let          current = gCurrentEssay,
			current.essayLength != 0,
			current.recordName  == essayRecordName {	// been here before

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

	// MARK: - note visibility
	// MARK: -

	func resetVisibilities() {
		visibilities.removeAll()

		if  let essay = gCurrentEssay,
			let  zone = essay.zone {
			if  !zone.hasChildNotes {
				visibilities.append(ZNoteVisibility(zone: zone))
			} else {
				for child in zone.zonesWithVisibleNotes {
					visibilities.append(ZNoteVisibility(zone: child))
				}
			}
		}
	}

	func drawVisibilityIcons(for index: Int, y: CGFloat, isANote: Bool) {
		if  gEssayTitleMode   != .sEmpty, !gHideNoteVisibility {
			var              v = visibilities[index]
			for type in ZNoteVisibilityIconType.all {
				if  !(type.forEssayOnly && isANote),
					let     on = v.stateFor(type),
					let  image = type.imageForVisibilityState(on) {
					let origin = CGPoint(x: bounds.maxX, y: y).offsetBy(-type.offset, .zero)
					let   rect = CGRect(origin: origin, size: .zero).expandedBy(image.size.dividedInHalf)

					v.setRect(rect, for: type)
					image.draw(in: rect)
				}
			}

			visibilities[index] = v
		}
	}

	func visibilityIconHit(at rect: CGRect) -> (Zone, ZNoteVisibilityIconType)? {
		if  !gHideNoteVisibility {
			for visibility in visibilities {
				for type in ZNoteVisibilityIconType.all {
					if  visibility.rectFor(type).intersects(rect) {
						return (visibility.zone, type)
					}
				}
			}
		}

		return nil
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
		isAutomaticSpellingCorrectionEnabled = false
		textContainerInset   = NSSize(width: margin, height: margin)

		resetForDarkMode()
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

	func essayViewSetup() {
		updateTextStorage()
		clearResizing()      // remove leftovers from last essay
	}

	@discardableResult func resetCurrentEssay(_ current: ZNote? = gCurrentEssay, selecting range: NSRange? = nil) -> Int {
		var           delta = 0
		if  let        note = current {
			essayRecordName = nil
			gCurrentEssay   = note

			note.updateChildren()

			delta           = updateTextStorage()

			note.updateNoteOffsets()
			note.updatedRangesFrom(note.noteTrait?.noteText)
			setNeedsDisplay()

			if  let r = range {
				FOREGROUND { [self] in
					selectAndScrollTo(r.offsetBy(delta))
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
		// grab record id of essay to indicate that this essay has not been saved
		// saves time by not needlessly overwriting it later

		resetForDarkMode()

		if  gCurrentEssay == nil {
			gControllers.swapMapAndEssay(force: .wMapMode)                            // not show blank essay
		} else {
			gEssayControlsView?.updateTitleSegments()

			delta = gEssayControlsView?.updateTitlesControlAndMode() ?? 0

			if  (shouldOverwrite || restoreSelection != nil),
				let text = gCurrentEssay?.essayText {

				discardPriorText()
				gCurrentEssay?.noteTrait?.whileSelfIsCurrentTrait { setText(text) }   // inject text
				selectAndScrollTo(restoreSelection)
				undoManager?.removeAllActions()                                       // clear the undo stack of prior / disastrous information (about prior text)
			}

			essayRecordName = gCurrentEssayZone?.recordName                           // do this after altering essay zone
			delegate        = self 					    	                          // set delegate after discarding prior and injecting current text

			if  gIsEssayMode {
				assignAsFirstResponder(self)                                 // show cursor and respond to key input
				gMainWindow?.setupEssayInspectorBar()

				gEssayControlsView?.setupEssayControls()
				gEssayControlsView?.enableEssayControls(true)
			}
		}

		return delta
	}

	func nextNotemark(down: Bool) {
		save()
		clearResizing()
		gFavorites.nextBookmark(down: down, amongNotes: true)
	}

	// MARK: - clean up
	// MARK: -

	func done() {
		prepareToExit()
		save()
		exit()
	}

	func exit() {
		prepareToExit()
		gControllers.swapMapAndEssay(force: .wMapMode)
	}

	func save() {
		if  let e = gCurrentEssay {
			e.saveAsEssay(textStorage)
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
		save()

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

	// MARK: - output
	// MARK: -

	override func draw(_ iDirtyRect: NSRect) {
		clearImageResizeRubberband()
		super.draw(iDirtyRect)

		if  iDirtyRect.width > 1.0 {
			drawSelectedImage()
			drawNoteDecorations()
		}
	}

	func drawNoteDecorations() {
		resetVisibilities()

		let dots = dragDots
		if  dots.count > 0 {
			for (index, dot) in dots.enumerated() {
				if  let     note = dot.note?.firstNote,
					let     zone = note.zone {
					let  grabbed = grabbedZones.contains(zone)
					let selected = note.noteRange.inclusiveIntersection(selectedRange) != nil
					let   filled = selected && !hasGrabbedNote
					let    color = dot.color

					drawVisibilityIcons(for: index, y: dot.dragRect.midY, isANote: !zone.hasChildNotes)  // draw visibility icons

					if  gEssayTitleMode == .sFull {
						dot.dragRect.drawColoredOval(color, thickness: 2.0, filled: filled || grabbed)   // draw drag dot

						if  let lineRect = dot.lineRect {
							drawColoredRect(lineRect, color, thickness: 0.5)             // draw indent line in front of drag dot
						}

						if  grabbed {
							drawColoredRect(dot.textRect, color)                         // draw box around entire note
						}
					}
				}
			}
		} else if let  note = gCurrentEssay, visibilities.count > 0,
				  let  zone = note.zone,
				  let     c = textContainer,
				  let     l = layoutManager {
			let        rect = l.boundingRect(forGlyphRange: note.noteRange, in: c)

			drawVisibilityIcons(for: 0, y: rect.minY + 33.0, isANote: !zone.hasChildNotes)                              // draw visibility icons
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
		let COMMAND = flags.hasCommand
		let CONTROL = flags.hasControl
		let OPTION  = flags.hasOption
		var SHIFT   = flags.hasShift
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
				case "n":      setGrabbedZoneAsCurrentEssay()
				case "t":      swapWithParent()
				case "/":      if SPECIAL { gHelpController?.show(flags: flags) } else { swapBetweenNoteAndEssay() }
				case kEquals:  if   SHIFT { grabSelected()                      } else { return followLinkInSelection() }
				case kEscape:  save(); if ANY { grabDone()                      } else { done() }
				case kReturn:  save(); if ANY { grabDone() }
				case kDelete:  deleteGrabbedOrSelected()
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
					case "d":  convertSelectedTextToChild(); return true
					case "e":  grabSelectedTextForSearch()
					case "f":  gSearching.showSearch(OPTION)
					case "g":  searchAgain(OPTION)
					case "i":  showSpecialCharactersPopup()
					case "l":  alterCase(up: false)
					case "p":  printCurrentEssay()
					case "s":  save()
					case "u":  if !OPTION { alterCase(up: true) }
					case "v":  if  SHIFT  { return pasteTextAndMatchStyle() }
					case "z":  if  SHIFT  { undoManager?.redo() } else { undoManager?.undo() }
					default:   break
				}
			}

			switch key {
				case "a":      selectAll(nil)
				case "j":      revealEmptyNotes(OPTION)
				case "n":      swapBetweenNoteAndEssay()
				case "t":      if let string = selectionString { showThesaurus(for: string) } else if OPTION { gControllers.showEssay(forGuide: false) } else { return false }
				case "u":      if OPTION { gControllers.showEssay(forGuide: true) } else { return false }
				case "/":      gHelpController?.show(flags: flags)
				case "]", "[": gFavorites.nextBookmark(down: key == "[", amongNotes: true); gRelayoutMaps()
				case kReturn:  if SEVERAL { grabSelectionHereDone() } else { save(); grabDone() }
				case kEquals:  if   SHIFT { grabSelected() } else { return followLinkInSelection() }
				case kDelete:  deleteGrabbedOrSelected()
				default:       return false
			}

			return true
		} else if CONTROL {
			switch key {
				case "/":      if gFavorites.popNoteAndUpdate() { updateTextStorage() }
				default:       if !enabled { return false } else {
					switch key {
						case "d": convertSelectedTextToChild()
						case "w": showLinkPopup()
						default:  return false
					}
				}
			}

			return true
		} else if OPTION, enabled {
			switch key {
				case "d": convertSelectedTextToChild()
				default:  return false
			}

			return true
		} else if key == kDelete {
			clearResizing()
		}

		return !enabled
	}

	func handleArrow(_ arrow: ZArrowKey, flags: ZEventFlags) {
		let   SHIFT = flags.hasShift
		let  OPTION = flags.hasOption
		let COMMAND = flags.hasCommand
		let SPECIAL = flags.exactlySpecial
		let SPLAYED = flags.exactlySplayed
		let     ALL = flags.exactlyAll

		if  hasGrabbedNote {
			handleGrabbed(arrow, flags: flags)
		} else if  lockedSelection {
			handlePlainArrow(arrow)
		} else if  SPECIAL {
			switch arrow {
				case .left:  fallthrough
				case .right: move(out: arrow == .left)
				default:     break
			}
		} else if  ALL {
			switch arrow {
				case .left:  break
				case .right: convertSelectionIntoChildIdeas(asSentences: true)
				default:     break
			}
		} else if  SPLAYED {
			switch arrow {
				case .right: convertSelectionIntoChildIdeas(asSentences: false)
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
			case .right: canRecurse = selectedRange.upperBound < gCurrentEssay?.upperBoundForLastNoteIn(selectedRange) ?? 0
			default:     break
		}

		switch arrow {
			case .left:  fallthrough
			case .right: setSelectedRange(selectedRange)     // work around stupid Apple bug
			default:     break
		}


		if  permitAnotherRecurse, canRecurse, lockedSelection {
			handlePlainArrow(arrow, permitAnotherRecurse: horizontal)
		}
	}

	func handleClick(with event: ZEvent) -> Bool { // true means do not further process this event
		var              result = true
		if  !gIgnoreEvents {
			let               rect = event.location(in: self)
			if  let         attach = hitTestForAttachment(in: rect) {
				selectedAttachment = attach
				resizeDragStart    = rect.origin
				resizeDot          = rectForRangedAttachment(attach)?.hitTestForResizeDot(in: rect)
				result             = resizeDot != nil

				setSelectedRange(attach.glyphRange)
				setNeedsDisplay()

			} else if let      dot = dragDotHit(at: rect),
					  let     note = dot.note {
				if  let      index = grabbedNotes.firstIndex(of: note) {
					grabbedNotes.remove(at: index)
				} else {
					if !event.modifierFlags.hasShift {
						ungrabAll()
					}

					grabbedNotes.appendUnique(item: note)
					setNeedsDisplay()
					gSignal([.sDetails])
				}
			} else if let (zone, type) = visibilityIconHit(at: rect),
					  let        trait = zone.maybeNoteOrEssayTrait {
				save()
				trait.toggleVisibilityFor(type)
				resetCurrentEssay()
				setNeedsDisplay()

				if  type != .tSelf, gCurrentEssay?.zone == zone {
					swapBetweenNoteAndEssay()
				}
			} else {
				ungrabAll()
				clearResizing()
				setNeedsDisplay()

				return false
			}
		}

		return result
	}

	@objc func handleButtonAction(_ iButton: ZHoverableButton) {
		if  let buttonID = ZEssayButtonID.essayID(for: iButton) {
			switch buttonID {
				case .idForward:  nextNotemark(down:  true)
				case .idBack:     nextNotemark(down: false)
				case .idSave:     save()
				case .idPrint:    printView()
				case .idHide:     grabDone()
				case .idDelete:   if !deleteGrabbedOrSelected() { gCurrentEssayZone?.deleteEssay(); exit() }
				case .idDiscard:                                  gCurrentEssayZone?.grab();        exit()
				default:          break
			}
		}
	}

	func pasteTextAndMatchStyle() -> Bool {
		if  let  clipboard = NSPasteboard.general.string(forType: .string) {
			let   insertMe = NSMutableAttributedString(string: clipboard)
			var attributes = selectedTextAttributes

			if  let   back = attributes[.backgroundColor] as? ZColor, back == .selectedTextBackgroundColor {
				attributes[.backgroundColor] = nil
			}

			if  let   fore = attributes[.foregroundColor] as? ZColor, fore == .selectedTextColor {
				attributes[.foregroundColor] = nil
			}

			insertMe.addAttributes(attributes, range: NSMakeRange(0, clipboard.length))
			insertText(insertMe, replacementRange: selectedRange())

			return true
		}

		return false
	}

	override func setAlignment(_ alignment: NSTextAlignment, range: NSRange) {
		super.setAlignment(alignment, range: range)

		if  selectedAttachment != nil {
			updateTextStorage(restoreSelection: selectedRange) // recompute resize rect (rubberband and dots)
		}
	}

	override func mouseDown(with event: ZEvent) {
		if  !handleClick   (with: event) {
			super.mouseDown(with: event)
			updateCursor    (for: event)
		}
	}

	override func mouseMoved(with event: ZEvent) {
//		super.mouseMoved(with: event) // not call super method: avoid a console warning when a linefeed is selected (sheesh!!!!)
		updateCursor(for: event)
	}

	// MARK: - locked ranges
	// MARK: -

	func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRange oldRange: NSRange, toCharacterRange newRange: NSRange) -> NSRange {
		let     noKeys = gCurrentKeyPressed == nil
		let     locked = gCurrentEssay?.isLocked(within: newRange) ?? false
		return (locked && noKeys) ? oldRange : newRange
	}

	func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString replacement: String?) -> Bool {
		setNeedsDisplay()        // so dots selecting image will be redrawn

		if  let replacementLength = replacement?.length,
			let         hasReturn = replacement?.containsLineEndOrTab,
			let (result,   delta) = gCurrentEssay?.shouldAlterEssay(in: range, replacementLength: replacementLength, hasReturn: hasReturn) {
			switch result {
				case .eAlter:        break
				case .eLock:         return false
				case .eExit: exit(); return false
				case .eDelete:
					FOREGROUND { [self] in                    // DEFER UNTIL AFTER THIS METHOD RETURNS ... avoids corrupting resulting text
						gCurrentEssay?.updateChildren()
						updateTextStorage(restoreSelection: NSRange(location: delta, length: range.length))		// recreate essay text and restore cursor position within it
					}
			}

			gCurrentEssay?.essayLength += delta           // compensate for change
		}

		return true // yes, change text
	}

	// MARK: - grabbing notes
	// MARK: -

	func handleGrabbed(_ arrow: ZArrowKey, flags: ZEventFlags) {

		// SHIFT single note expand to essay and vice-versa

		let indents = relativeLevelOfFirstGrabbed

		if  flags.hasOption {
			if (arrow == .left && indents > 1) || ([.up, .down, .right].contains(arrow) && indents > 0) {
				save()

				gMapEditor.handleArrow(arrow, flags: flags) { [self] in
					resetTextAndGrabs()
				}
			}
		} else if flags.hasShift {
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
			grabNextNote(up: arrow == .up, ungrab: !flags.hasShift)
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
		var    grabbed : ZEssayDragDot?

		for dot in dragDots {
			if  let zone = dot.note?.zone,
				grabbedZones.contains(zone) {
				grabbed  = dot
			}
		}

		return grabbed
	}

	var dragDots : ZEssayDragDotArray {
		var dots = ZEssayDragDotArray()

		if  let essay = gCurrentEssay, !essay.isNote,
			let  zone = essay.zone,
			let     l = layoutManager,
			let     c = textContainer {
			let zones = zone.zonesWithVisibleNotes
			let level = zone.level

			essay.updateNoteOffsets()

			for (index, zone) in zones.enumerated() {
				if  var note       = zone.note {
					if  index     == 0 {
						note       = essay
					}

					let dragHeight = 15.0
					let  dragWidth = 11.75
					let      inset = CGFloat(2.0)
					let     offset = index == 0 ? 0 : 1               // first note has an altered offset ... thus, an altered range
					let     indent = zone.level - level
					let     noLine = indent == 0
					let      color = zone.color ?? kDefaultIdeaColor
					let  noteRange = note.noteRange.offsetBy(offset)
					let   noteRect = l.boundingRect(forGlyphRange: noteRange, in: c).offsetBy(dx: 18.0, dy: margin + inset + 1.0).expandedEquallyBy(inset)
					let lineOrigin = noteRect.origin.offsetBy(CGPoint(x: 3.0, y: dragHeight - 2.0))
					let  lineWidth = dragWidth * Double(indent)
					let   lineSize = CGSize(width: lineWidth, height: 0.5)
					let   lineRect = noLine ? nil : CGRect(origin: lineOrigin, size: lineSize)
					let dragOrigin = lineOrigin.offsetBy(CGPoint(x: lineWidth, y: dragHeight / -2.0))
					let   dragSize = CGSize(width: dragWidth, height: dragHeight)
					let   dragRect = CGRect(origin: dragOrigin, size: dragSize)
					let        dot = ZEssayDragDot(color: color, dragRect: dragRect, textRect: noteRect, lineRect: lineRect, noteRange: noteRange, note: note)

					dots.append(dot)
				}
			}
		}

		return dots
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
			gSignal([.sDetails])
		}
	}

	func scrollToGrabbed() {
		if  let range = lastGrabbedDot?.noteRange {
			scrollRangeToVisible(range)
		}
	}

	func swapWithParent() {
		if !firstIsGrabbed,
		   let note = firstGrabbedNote,
		   let zone = note.zone {
			save()
			gCurrentEssayZone?.clearAllNoteMaybes()            // discard current essay text and all child note's text
			ungrabAll()

			gNeedsRecount = true
			let    parent = zone.parentZone                  // get the parent before we swap
			let     reset = parent == firstNote?.zone        // check if current esssay should change

			gDisablePush {
				zone.swapWithParent { [self] in
					if  reset {
						gCurrentEssay = gCreateEssay(zone)
					}

					resetTextAndGrabs(grab: parent)
				}
			}
		}
	}

	func setGrabbedZoneAsCurrentEssay() {
		if  let      note = firstGrabbedNote {
			gCurrentEssay = note

			ungrabAll()
			resetTextAndGrabs()
		}
	}

	@discardableResult func deleteGrabbedOrSelected() -> Bool {
		save() // capture all the current changes before deleting

		if  hasGrabbedNote {
			for zone in grabbedZones {
				zone.deleteNote()
			}

			ungrabAll()
			resetTextAndGrabs()

			return true
		}

		if  let  zone = selectedNotes.last?.zone,
			let count = gCurrentEssay?.zone?.zonesWithNotes.count, count > 1 {
			zone.deleteNote()
			resetTextAndGrabs()

			return true
		}

		return false
	}

	func ungrabAll() { grabbedNotes.removeAll() }

	func regrab(_ ungrabbed: ZoneArray) {
		for zone in ungrabbed {                       // re-grab notes for set aside zones
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
				gCurrentEssay = gCreateEssay(first)
			}
		}

		return grabbed
	}

	func resetTextAndGrabs(grab: Zone? = nil) {
		let     grabbed = willRegrab(grab)              // includes logic for optional grab parameter
		essayRecordName = nil                           // so shouldOverwrite will return true

		gCurrentEssayZone?.clearAllNoteMaybes()         // discard current essay text and all child note's text
		updateTextStorage()                             // assume text has been altered: re-assemble it
		regrab(grabbed)
		scrollToGrabbed()
		gSignal([.spCrumbs, .sDetails])
	}

	// MARK: - search
	// MARK: -

	func grabSelectedTextForSearch() {
		gSearching.essaySearchText = selectionString
	}

	func performSearch(for searchString: String, closure: Closure?) {
		gSearching.essaySearchText = searchString

		searchAgain(false, closure: closure)
	}

	func searchAgain(_ OPTION: Bool, closure: Closure? = nil) {
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

		closure?()

		if  matches != nil,
			matches!.count > 0 {
			assignAsFirstResponder(self)
			setSelectedRange(matches![0].offsetBy(offset))
			scrollToVisible(selectionRect.expandedEquallyBy(100.0))
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

							FOREGROUND { [self] in
								if  let  note = target.noteMaybe, gCurrentEssay?.children.contains(note) ?? false {
									let range = note.noteTextRange	    // text range of target essay
									let start = NSRange(location: range.location, length: 1)

									setSelectedRange(range)

									if  let    r = rectForRange(start) {
										let rect = convert(r, to: self).offsetBy(dx: .zero, dy: -150.0)

										// highlight text of note, and scroll it to visible

										scroll(rect.origin)
									}
								} else {
									gCreateCombinedEssay = type == .hEssay

									target .asssureIsVisible()		   // for later, when user exits essay mode
									common?.asssureIsVisible()
									resetCurrentEssay(target.note)     // change current note to that of target
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

	// MARK: - child notes
	// MARK: -

	func revealEmptyNotes(_ conceal: Bool = false) {
		if  let essay = gCurrentEssay,
			let  zone = essay.zone {
			gCreateCombinedEssay = false              // so createNote does the right thing

			zone.traverseAllProgeny { child in
				if  conceal {
					if  let string = child.maybeTraitFor(.tNote)?.text,
						string == kDefaultNoteText {
						child.deleteNote()
					}
				} else {
					if !child.hasNoteOrEssay {
						child.setTraitText(kDefaultNoteText, for: .tNote)  // create an empty note trait, add to child
					}
				}
			}

			zone.clearAllNoteMaybes()                 // discard current essay text and all child note's text

			gCreateCombinedEssay = true               // so gCreateEssay does the right thing
			gCurrentEssay        = gCreateEssay(zone) // create a new essay from the zone

			resetCurrentEssay(gCurrentEssay)
		}
	}

	func swapBetweenNoteAndEssay() {
		let       range = selectedRange()
		if  var    note = gCurrentEssay?.notes(in: range).first,
			let    zone = note.zone {
			let noChild = note.children.count == 0
			let toEssay = noChild || !gCreateCombinedEssay

			if  toEssay, gEssayTitleMode == .sEmpty, note.essayText!.string.length > 0 {
				note.updatedRangesFrom(textStorage)
			}

			save()

			gCreateCombinedEssay = toEssay      // toggle

			if  toEssay {
				zone.clearAllNoteMaybes()            // discard current essay text and all child note's text

				note = gCreateEssay(zone)       // create a new essay from the zone
			} else {
				ungrabAll()

				if !note.isNote {
					note = ZNote(note.zone)     // convert essay to note
				}
			}

			resetCurrentEssay(note, selecting: range)
			gSignal([.sDetails])
		}
	}

	func move(out: Bool) {
		gCreateCombinedEssay = true
		let            range = selectedRange()
		let             note = gCurrentEssay?.notes(in: range).first
		let            prior = (note?.noteOffset ?? 0) + (note?.indentCount ?? 0)

		save()

		if  out {
			gCurrentEssayZone?.traverseAncestors { ancestor -> (ZTraverseStatus) in
				if  ancestor != gCurrentEssayZone, ancestor.hasNote,
					let essay = ancestor.note {
					let delta = resetCurrentEssay(essay)

					if  let zone = note?.zone {
						for within in essay.children {
							if  zone == within.zone {
								let offset = within.noteOffset
								let indent = within.indentCount
								let select = range.offsetBy(offset + delta + indent - prior + 1)

								selectAndScrollTo(select)
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
			let   delta = resetCurrentEssay(n)
			let  select = range.offsetBy(delta - offset - adjust + 1)

			selectAndScrollTo(select)
		}

		gSignal([.spCrumbs])
	}

	func resetAndSelect(_ zone: Zone?) {
		resetCurrentEssay()

		if  let range = zone?.note?.noteTextRange {
			setSelectedRange(range)
		}
	}

	func convertSelectionIntoChildIdeas(asSentences: Bool) {
		if  let    parent = selectedZone,
			let    string = selectionString {
			let separator = asSentences ? ". " : kNewLine
			let     ideas = string.components(separatedBy: separator)
			var      zone : Zone?

			insertText(kDefaultNoteText, replacementRange: selectedRange)       // remove selected text

			for idea in ideas {                                                 // create a child idea from each
				zone = createNoteNamed(idea, in: parent, atEnd: true)           // add them as notes to the essay
			}

			resetAndSelect(zone)
		}
	}

	private func convertSelectedTextToChild() {
		if  let   parent = selectedZone,
			let   string = selectionString {

			insertText(kEmpty, replacementRange: selectedRange)	                // remove selected text

			if  let zone = createNoteNamed(string, in: parent) {
				resetAndSelect(zone)
			}
		}
	}

	private func createNoteNamed(_ name: String?, in parent: Zone, atEnd: Bool = false) -> Zone? {
		var      child : Zone?
		if  let   text = name, text.length > 0 {
			let   dbID = parent.databaseID
			let  index = atEnd ? parent.count : 0
			child      = Zone.uniqueZoneNamed(text, databaseID: dbID)           // create new zone from text

			gCreateCombinedEssay = parent.zonesWithVisibleNotes.count > 0

			save()
			parent.addChildNoDuplicate(child, at: index)                        // add as new child of parent
			child?.setTraitText(text, for: .tNote, addDefaultAttributes: true)
		}

		return child
	}

	// MARK: - selection
	// MARK: -

	private func alterCase(up: Bool) {
		if  let        text = selectionString {
			let replacement = up ? text.uppercased() : text.lowercased()

			insertText(replacement, replacementRange: selectedRange)
			setSelectionNeedsSaving()
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
			setSelectionNeedsSaving()
		}
	}

	func setSelectionNeedsSaving() {
		for note in selectedNotes {
			note.needsSave = true
		}
	}

	// change cursor to
	// indicate action possible on what's under cursor
	// and possibly display a tool tip

	func updateCursor(for event: ZEvent) {
		let rect = event.location(in: self)

		if  linkHit(at: rect) {
			NSCursor.arrow.set()
		} else if let   dot = dragDotHit(at: rect) {
			if  let    note = dot.note {
				let grabbed = grabbedNotes.contains(note)
				toolTip     = note.toolTipString(grabbed: grabbed)
			}

			NSCursor.arrow.set()
		} else if let    attach = hitTestForAttachment(in: rect) {
			if  let         dot = rectForRangedAttachment(attach)?.hitTestForResizeDot (in: rect) {
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
			let     endRange = NSRange(location: text.length, length: 0) // immediately beyond final character of text
			let       common = range.intersection(storageRange) ?? endRange

			super.setSelectedRange(common)

			if  let        rect = rectForRange(common) {
				selectionRect   = rect
			}
		}
	}

	func selectFirstNote() {
		if  let essay = gCurrentEssay, essay.children.count > 0 {
			let child = essay.children[0]
			let range = child.textRange
			setSelectedRange(range)
		}
	}

	private func selectAndScrollTo(_ range: NSRange? = nil) {
		var        point = CGPoint()                          // scroll to top
		if  let    essay = gCurrentEssay,
			(essay.lastTextIsDefault || range != nil),
			let range    = range ?? essay.lastTextRange {     // default: select entire text of final essay

			if  let rect = rectForRange(range) {
				point    = rect.origin
				point .y = max(.zero, point.y - 100.0)
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

}

