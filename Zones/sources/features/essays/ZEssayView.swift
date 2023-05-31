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

var gEssayView: ZEssayView? {
	if  let e = gEssayController, e.essayView == nil {
		e.essayControlsView?.updateTitlesControlAndMode()
	}

	return gEssayController?.essayView
}

@objc (ZEssayView)
class ZEssayView: ZTextView, ZTextViewDelegate, ZSearcher {
	let margin             = CGFloat(20.0)
	var dropped            = StringsArray()
	var visibilities       = ZNoteVisibilityArray()
	var grabbedNotes       = ZNoteArray()
	var selectionRect      = CGRect()  { didSet { if selectionRect.origin == .zero { selectedAttachment = nil } } }
	var selectedNote       : ZNote?    { return selectedNotes.last ?? gCurrentEssay }
	var selectedZone       : Zone?     { return selectedNote?.zone }
	var lockedSelection    : Bool      { return gCurrentEssay?.isLocked(within: selectedRange) ?? false }
	var selectionString    : String?   { return textStorage?.attributedSubstring(from: selectedRange).string }
	var essayRecordName    : String?
	var resizeDragStart    : CGPoint?
	var resizeDragRect     : CGRect?
	var resizeDot          : ZDirection?
	var selectedAttachment : ZRangedAttachment?

	var selectedNotes : ZNoteArray {
		guard let essay = gCurrentEssay else {
			return ZNoteArray() // empty because current essay is nil
		}

		essay.updateNoteOffsets()

		return (essay.zone?.zonesWithVisibleNotes.filter {
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

	var needsSave : Bool {
		get { return gCurrentEssay?.needsSave ?? false }
		set {        gCurrentEssay?.needsSave  = newValue }
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
		if !gHideNoteVisibility {
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

		usesRuler                            = true
		isRulerVisible                       = true
		importsGraphics                      = true
		usesInspectorBar                     = true
		allowsImageEditing                   = true
		displaysLinkToolTips                 = true
		isAutomaticSpellingCorrectionEnabled = false
		textContainerInset                   = NSSize(width: margin, height: margin)

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

		if  gCurrentEssay == nil {                           // make sure we actually have a current essay
			gSwapMapAndEssay(force: .wMapMode)   // not show blank essay
		} else {
			delta = gEssayControlsView?.updateTitlesControlAndMode() ?? 0

			updateTextStorageRestoringSelection(restoreSelection)
		}

		return delta
	}

	func updateTextStorageRestoringSelection(_ range: NSRange?) {

		// activate the buttons in the control bar
		// grab the current essay text and put it in place
		// grab record id of essay to indicate that this essay has not been saved
		// saves time by not needlessly overwriting it later

		updateTracking()
		gEssayControlsView?.updateTitleSegments()
		resetForDarkMode()
		save()

		if  (shouldOverwrite || range != nil),
			let text = gCurrentEssay?.essayText {

			discardPriorText()
			gCurrentEssay?.noteTrait?.whileSelfIsCurrentTrait { setNoteText(text) }   // inject text
			selectAndScrollTo(range)
			undoManager?.removeAllActions()                                       // clear the undo stack of prior / disastrous information (about prior text)
		}

		essayRecordName = gCurrentEssayZone?.recordName                           // do this after altering essay zone
		delegate        = self 					    	                          // set delegate after discarding prior and injecting current text

		if  gIsEssayMode {
			assignAsFirstResponder(self)                                          // show cursor and respond to key input
			gMainWindow?       .setupEssayInspectorBar()
			gEssayControlsView?.setupEssayControls()
			gEssayControlsView?.enableEssayControls(true)
		}
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
		gSwapMapAndEssay(force: .wMapMode)
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
		if  let zone = lastGrabbedDot?.dotNote?.zone {
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

	// MARK: - input
	// MARK: -

	@discardableResult func handleKeyInEssayView(_ iKey: String?, flags: ZEventFlags) -> Bool {   // false means key not handled
		guard var key = iKey, !gRefusesFirstResponder else {
			return false
		}

		let enabled = gHasEnabledSubscription
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
			handleArrowInEssay(arrow, flags: flags)

			return true
		} else if  hasGrabbedNote {
			switch key {
				case "c":      grabbedZones.copyToPaste()
				case "n":      setGrabbedZoneAsCurrentEssay()
				case "t":      swapGrabbedWithParent()
				case kSlash:   if SPECIAL { gHelpController?.show(flags: flags) } else { swapBetweenNoteAndEssay() }
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
					case "b":      applyToSelection(BOLD: true)
					case "d":      convertSelectedTextToChild(); return true
					case "e":      grabSelectedTextForSearch()
					case "f":      gSearching.showSearch(OPTION)
					case "g":      searchAgain(OPTION)
					case "i":      showSpecialCharactersPopup()
					case "l":      alterCase(up: false)
					case "p":      printCurrentEssay()
					case "s":      save()
					case "u":      if !OPTION { alterCase(up: true) }
					case "v":      if  SHIFT  { return pasteTextAndMatchStyle() }
					case "z":      if  SHIFT  { undoManager?.redo() } else { undoManager?.undo() }
					default:       break
				}
			}

			if  key == "j" { revealEmptyNotes(OPTION) }

			if  OPTION {
				switch key {
					case "t":      gShowEssay(forGuide: false)
					case "u":      gShowEssay(forGuide: true)
					default:       return false
				}
			} else {
				switch key {
					case "a":      selectAll(nil)
					case "n":      swapBetweenNoteAndEssay()
					case "t":      if let string = selectionString { showThesaurus(for: string) } else { return false }
					case "]", "[": gFavoritesCloud.nextBookmark(down: key == "[", amongNotes: true); gRelayoutMaps()
					case kSlash:   gHelpController?.show(flags: flags)
					case kReturn:  if SEVERAL { grabSelectionHereDone() } else { save(); grabDone() }
					case kEquals:  if   SHIFT { grabSelected() } else { return followLinkInSelection() }
					case kDelete:  deleteGrabbedOrSelected()
					default:       return false
				}
			}

			return true
		} else if CONTROL {
			switch key {
				case kSlash:   if gFavoritesCloud.popNoteAndUpdate() { updateTextStorage() }
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

	func handleArrowInEssay(_ arrow: ZArrowKey, flags: ZEventFlags) {
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

	override func mouseDown(with event: ZEvent) {
		if  !handleEssayViewClick(with: event) {
			super.mouseDown      (with: event)
			mouseMoved           (with: event)
		}
	}

	func handleEssayViewClick(with event: ZEvent) -> Bool { // true means do not further process this event
		var                 result = true
		if  !gPreferencesAreTakingEffect {
			let               rect = event.locationRect(in: self)
			if  let         attach = hitTestForAttachment(in: rect) {
				selectedAttachment = attach
				resizeDragStart    = rect.origin
				resizeDot          = attach.glyphRect(for: textStorage, margin: margin)?.hitTestForResizeDot(in: rect)
				result             = resizeDot != nil

				setSelectedRange(attach.glyphRange)
				setNeedsDisplay()

			} else if let      dot = dragDotHit(at: rect),
					  let     note = dot.dotNote {
				if !ungrabNote(note){
					if !event.modifierFlags.hasShift {
						ungrabAll()
					}

					grabNote(note)
					setNeedsDisplay()
					gDispatchSignals([.sDetails])
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

	// MARK: - locked ranges
	// MARK: -

	func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRange oldRange: NSRange, toCharacterRange newRange: NSRange) -> NSRange {
		let     noKeys = gCurrentKeyPressed == nil
		let     locked = gCurrentEssay?.isLocked(within: newRange) ?? false
		return (locked && noKeys) ? oldRange : newRange
	}

	func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString replacement: String?) -> Bool {
		setNeedsDisplay()                                 // so image resize rubberband will be redrawn

		if  let replacementLength = replacement?.length,
			let         hasReturn = replacement?.containsLineEndOrTab,
			let   (result, delta) = gCurrentEssay?.shouldAlterEssay(in: range, replacementLength: replacementLength, hasReturn: hasReturn) {
			switch result {
				case .eAlter:        break
				case .eLock:         return false
				case .eExit: exit(); return false
				case .eDelete:
					FOREGROUND { [self] in                // DEFER UNTIL AFTER THIS METHOD RETURNS ... avoids corrupting resulting text
						gCurrentEssay?.updateChildren()
						updateTextStorage(restoreSelection: NSRange(location: delta, length: range.length))		// recreate essay text and restore cursor position within it
					}
			}

			gCurrentEssay?.essayLength += delta           // compensate for change
		} else {
			updateImageInParagraph(containing: range)     // so image resize rubberband gets relocated correctly
		}

		return true // yes, change text
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

	func followLinkInSelection() -> Bool {
		if  let  link = currentLink as? String {
			let parts = link.componentsSeparatedByColon

			if  parts.count > 1,
				let  one = parts.first?.first,                             // first character of first part
				let name = parts.last,
				let type = ZEssayLinkType(rawValue: String(one)) {
				let zone = gRemoteStorage.maybeZoneForRecordName(name)  // find zone whose record name == name
				switch type {
					case .hEmail:
						link.openAsURL()
						return true
					case .hFile:
						gFilesRegistry.fileWith(name, in: gDatabaseID)?.activate()

						return true
					case .hIdea:
						if  let  grab = zone {
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
						if  let target = zone {

							save()

							let common = gCurrentEssayZone?.closestCommonParent(of: target)

							FOREGROUND { [self] in
								if  let  note = target.noteMaybe, gCurrentEssay?.childrenNotes.contains(note) ?? false {
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
									gDispatchSignals([.spFavoritesMap, .spCrumbs])
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
			let noChild = note.childrenNotes.count == 0
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
			gDispatchSignals([.sDetails])
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
						for within in essay.childrenNotes {
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

		gDispatchSignals([.spCrumbs])
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
			let   databaseID = parent.databaseID
			let  index = atEnd ? parent.count : 0
			child      = Zone.uniqueZoneNamed(text, databaseID: databaseID)     // create new zone from text

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
		if  let essay = gCurrentEssay, essay.childrenNotes.count > 0 {
			let child = essay.childrenNotes[0]
			let range = child.textRange
			setSelectedRange(range)
		}
	}

	func selectAndScrollTo(_ range: NSRange? = nil) {
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

