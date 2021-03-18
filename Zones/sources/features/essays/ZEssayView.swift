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

struct ZEssayDragDot {
	var  note : ZNote?
	var range : NSRange?
	var color = kWhiteColor
	var  rect = CGRect.zero
}

class ZEssayView: ZTextView, ZTextViewDelegate {
	let dotInset        = CGFloat(-5.0)
	var dropped         = [String]()
	var grabbedNotes    = [ZNote]()
	var selectionRect   = CGRect()           { didSet { if selectionRect.origin != CGPoint.zero { imageAttachment = nil } } }
	var imageAttachment : ZRangedAttachment? { didSet { if imageAttachment != nil { setSelectedRange(NSRange()) } else if oldValue != nil { eraseAttachment = oldValue } } }
	var eraseAttachment : ZRangedAttachment?
	var lockedSelection : Bool               { return gCurrentEssay?.isLocked(within: selectedRange) ?? false }
	var selectionString : String?            { return textStorage?.attributedSubstring(from: selectedRange).string }
	var selectionZone   : Zone?              { return selectedNotes.first?.zone }
	var backwardButton  : ZButton?
	var forwardButton   : ZButton?
	var cancelButton    : ZButton?
	var deleteButton    : ZButton?
	var titlesButton    : ZButton?
	var hideButton      : ZButton?
	var saveButton      : ZButton?
	var resizeDragStart : CGPoint?
	var resizeDragRect  : CGRect?
	var resizeDot       : ZDirection?
	var essayID         : CKRecordID?

	var shouldOverwrite: Bool {
		if  let          current = gCurrentEssay,
			current.maybeNoteTrait?.needsSave ?? false,
			current.essayLength != 0,
			let i                = gCurrentEssayZone?.ckRecord?.recordID,
			i                   == essayID {	// been here before

			return false						// has not yet been saved. don't overwrite
		}

		return true
	}

	// MARK:- setup
	// MARK:-

	func done() { save(); exit() }

	func exit() {
		if  let e = gCurrentEssay,
			e.lastTextIsDefault,
			e.autoDelete {
			e.zone?.deleteNote()
		}

		gControllers.swapMapAndEssay(force: .wMapMode)
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
		importsGraphics        = true
		allowsImageEditing     = true
		displaysLinkToolTips   = true
		textContainerInset     = NSSize(width: 20, height: 0)
		zlayer.backgroundColor = kClearColor.cgColor
		backgroundColor        = kClearColor

		FOREGROUND { // wait for application to fully load the inspector bar
			gMainWindow?.updateEssayEditorInspectorBar(show: true)

			for tag in ZEssayButtonID.all {
				self.addButtonFor(tag)
			}
		}
	}

	private func discardPriorText() {
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

		if  gCurrentEssay == nil {
			gWorkMode = .wMapMode // not show blank essay
		} else {
			essayID   = gCurrentEssayZone?.ckRecord?.recordID

			setControlBarButtons(enabled: true)

			if  (shouldOverwrite || restoreSelection != nil),
				let text = gCurrentEssay!.essayText {
				discardPriorText()
				gCurrentEssay?.noteTrait?.setCurrentTrait { setText(text) }	     // emplace text
				select(restoreSelection: restoreSelection)
			}

			delegate = self 					    	 // set delegate after setText

			if  gIsEssayMode {
				gMainWindow?.makeFirstResponder(self)    // this should never happen unless already in essay mode
			}
		}
	}

	// MARK:- buttons
	// MARK:-

	func setControlBarButtons(       enabled: Bool) {
		let      hasMultipleNotes =  gCurrentSmallMapRecords?.workingNotemarks.count ?? 0 > 1
		let               isEssay = (gCurrentEssay?.isNote ?? true) == false
		let                   bar =  gMainWindow?.inspectorBar
		backwardButton?.isEnabled =  enabled && hasMultipleNotes
		forwardButton? .isEnabled =  enabled && hasMultipleNotes
		titlesButton?  .isEnabled =  enabled && isEssay
		deleteButton?  .isEnabled =  enabled
		cancelButton?  .isEnabled =  enabled
		hideButton?    .isEnabled =  enabled
		saveButton?    .isEnabled =  enabled
		bar?            .isHidden = !enabled

		if  let b = bar {
			b.draw(b.bounds)
		}
	}

	@objc private func handleButtonPress(_ iButton: ZButton) {
		if  let buttonID = ZEssayButtonID(rawValue: iButton.tag) {
			switch buttonID {
				case .idForward: gCurrentSmallMapRecords?.go(down:  true, amongNotes: true) { gRedrawMaps() }
				case .idBack:    gCurrentSmallMapRecords?.go(down: false, amongNotes: true) { gRedrawMaps() }
				case .idSave:    save()
				case .idHide:    gCurrentEssayZone?.grab();        done()
				case .idCancel:  gCurrentEssayZone?.grab();        exit()
				case .idDelete:  gCurrentEssayZone?.deleteNote(); exit()
				case .idTitles:  toggleEssayTitles()
			}
		}
	}

	func updateButtonTitles() {
		for tag in ZEssayButtonID.all {
			var button :ZButton?
			switch tag {
				case .idBack:    button = backwardButton
				case .idForward: button =  forwardButton
				case .idCancel:  button =   cancelButton
				case .idDelete:  button =   deleteButton
				case .idTitles:  button =   titlesButton
				case .idHide:    button =     hideButton
				case .idSave:    button =     saveButton
			}

			if  button?.image == nil {
				button?.title = tag.title
			}
		}
	}

	func toggleEssayTitles() {
		gShowEssayTitles = !gShowEssayTitles

		updateText()
	}

	private func addButtonFor(_ tag: ZEssayButtonID) {
		if  let inspectorBar = gMainWindow?.inspectorBar {

			func rect(at target: Int) -> CGRect {

				// ////////////////////////////////////////////////// //
				// Apple bug: subviews are not located where expected //
				// ////////////////////////////////////////////////// //

				var final = inspectorBar.subviews[0].frame
				var prior = final

				for index in 1...target {
					let subview      = inspectorBar.subviews[index]
					let frame        = subview.frame
					subview.isHidden = false
					final.origin.x  += prior.size.width
					final.size       = frame.size
					prior            = frame
				}

				final.origin.x      += 70.0

				return final
			}

			func buttonWith(_ title: String) -> ZTooltipButton {
				let    action = #selector(handleButtonPress)

				if  let image = ZImage(named: title)?.resize(CGSize(width: 14.0, height: 14.0)) {
					return      ZTooltipButton(image: image, target: self, action: action)
				}

				let    button = ZTooltipButton(title: title, target: self, action: action)
				button  .font = gTinyFont

				return button
			}

			func buttonFor(_ tag: ZEssayButtonID) -> ZTooltipButton {
				let         index = inspectorBar.subviews.count - 1
				var         frame = rect(at: index).offsetBy(dx: 2.0, dy: -5.0)
				let         title = tag.title
				let        button = buttonWith(title)
				frame       .size = button.bounds.size
				frame             = frame.insetBy(dx: 12.0, dy: 6.0)
				button   .toolTip = "\(kClickTo)\(tag.tooltipString)"
				button       .tag = tag.rawValue
				button     .frame = frame
				button .isEnabled = false
				button.isBordered = false
				button.bezelStyle = .texturedRounded

				button.setButtonType(.momentaryChange)
				button.updateTracking() // for tool tip

				return button
			}

			func setButton(_ button: ZButton) {
				if  let    tag = ZEssayButtonID(rawValue: button.tag) {
					switch tag {
						case .idBack:   backwardButton = button
						case .idForward: forwardButton = button
						case .idCancel:   cancelButton = button
						case .idDelete:   deleteButton = button
						case .idTitles:   titlesButton = button
						case .idHide:       hideButton = button
						case .idSave:       saveButton = button
					}
				}
			}

			let b = buttonFor(tag)

			inspectorBar.addSubview(b)
			setButton(b)
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
		drawDragDots()

		if  imageAttachment != nil {
			gActiveColor.setStroke()
			gActiveColor.setFill()
		} else {
			kClearColor .setStroke()
			kClearColor .setFill()
		}

		if  let       rect = resizeDragRect {
			let       path = ZBezierPath(rect: rect)
			let    pattern : [CGFloat] = [4.0, 4.0]
			path.lineWidth = CGFloat(gLineThickness * 3.0)
			path.flatness  = 0.0001

			path.setLineDash(pattern, count: 2, phase: 4.0)
			path.stroke()
			drawImageResizeDots(onBorderOf: rect)
		} else if let attach = imageAttachment ?? eraseAttachment,
				  let   rect = rectForRangedAttachment(attach) {
			drawImageResizeDots(onBorderOf: rect)
		}
	}

	func drawImageResizeDots(onBorderOf rect: CGRect) {
		for point in rect.selectionPoints.values {
			let   dotRect = CGRect(origin: point, size: CGSize.zero).insetEquallyBy(dotInset)
			let      path = ZBezierPath(ovalIn: dotRect)
			path.flatness = 0.0001

			path.fill()
		}
	}

	func drawDragDots() {
		for dot in dragDots {
			if  let    note = dot.note {
				let grabbed = grabbedNotes.contains(note)
				let   color = grabbed ? kBlackColor : dot.color
				let  filled = dot.range?.intersects(selectedRange) ?? false

				drawColoredOval(dot.rect, color, filled: filled)
			}
		}
	}

	// MARK:- input
	// MARK:-

	func handleKey(_ iKey: String?, flags: ZEventFlags) -> Bool {   // false means key not handled
		guard var key = iKey else {
			return false
		}

		let COMMAND = flags.isCommand
		let CONTROL = flags.isControl
		let  OPTION = flags.isOption
		let     ALL = OPTION && CONTROL

		if  key    != key.lowercased() {
			key     = key.lowercased()
		}

		if  let arrow = key.arrow {
			handleArrow(arrow, flags: flags)

			return true
		} else if  COMMAND {
			switch key {
				case "a":      selectAll(nil)
				case "d":      convertToChild(createEssay: ALL)
				case "e":      grabSelectedTextForSearch()
				case "f":      gSearching.showSearch(OPTION)
				case "g":      searchAgain(OPTION)
				case "i":      showSpecialCharactersPopup()
				case "l":      alterCase(up: false)
				case "n":      swapBetweenNoteAndEssay()
				case "p":      printCurrentEssay()
				case "s":      save()
				case "t":      if OPTION { gControllers.showEssay(forGuide: false) } else { return false }
				case "u":      if OPTION { gControllers.showEssay(forGuide:  true) } else { alterCase(up: true) }
				case "/":                  gHelpController?.show(flags: flags)
				case "}", "{": gCurrentSmallMapRecords?.go(down: key == "}", amongNotes: true) { gRedrawMaps() }
				case "]", "[": gRecents                .go(down: key == "]", amongNotes: true) { gRedrawMaps() }
				case kReturn:  gCurrentEssayZone?.grab(); done()
				default:       return false
			}

			return true
		} else if key == kEscape {
			if  OPTION {
				accountForSelection()
			}

			gControllers.swapMapAndEssay()

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

	func handleArrow(_ arrow: ZArrowKey, flags: ZEventFlags) {
		let   SHIFT = flags.isShift
		let  OPTION = flags.isOption
		let COMMAND = flags.isCommand

		if         COMMAND && OPTION {
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
		let            rect = rectFromEvent(event)
		if  let      attach = attachmentHit(at: rect) {
			resizeDot       = resizeDotHit(in: attach, at: rect)
			resizeDragStart = rect.origin
			imageAttachment = attach

			return resizeDot != nil // true means do not further process this event
		} else if let   dot = dragDotHit(at: rect),
				  let  note = dot.note {
			grabbedNotes.append(note)
			print("\(note.zone!)")

			return true
		}

		clearResizing()
		setNeedsDisplay()

		return false
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

	override func mouseDown(with event: ZEvent) {
		if  !handleClick   (with: event) {
			super.mouseDown(with: event)
		}
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
				let cornerRect = CGRect(origin: point, size: CGSize.zero).insetEquallyBy(dotInset)

				if  cornerRect.intersects(rect) {
					NSCursor.crosshair.set()
				}
			}
		}
	}

	override func setSelectedRange(_ range: NSRange) {
		super.setSelectedRange(range)

		if  selectedRange.location != 0,
			let      rect = rectForRange(selectedRange) {
			selectionRect = rect
		}
	}

	// MARK:- prevent editing added [locked] whitespace
	// MARK:-

	func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRange oldSelectedCharRange: NSRange, toCharacterRange newSelectedCharRange: NSRange) -> NSRange {
		let     noKeys = gCurrentKeyPressed == nil
		let     locked = gCurrentEssay?.isLocked(within: newSelectedCharRange) ?? false
		return (locked && noKeys) ? oldSelectedCharRange : newSelectedCharRange
	}

	func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString replacement: String?) -> Bool {
		if  let   replacementLength = replacement?.length,
			let   (result,   delta) = gCurrentEssay?.shouldAlterEssay(range, replacementLength: replacementLength) {
			switch result {
				case .eAlter: return true
				case .eLock:  return false
				case .eExit:  gControllers.swapMapAndEssay()
				case .eDelete:
					FOREGROUND {										// DEFER UNTIL AFTER THIS METHOD RETURNS ... avoids corrupting resulting text
						gCurrentEssay?.reset()
						self.updateText(restoreSelection: delta)		// recreate essay text and restore cursor position within it
					}
			}

			gCurrentEssay?.essayLength += delta							// compensate for change

			return true
		}

		return replacement == nil
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

	var dragDots:  [ZEssayDragDot] {
		var dots = [ZEssayDragDot]()

		if  let essay = gCurrentEssay, !essay.isNote,
			let zones = essay.zone?.zonesWithNotes,
			let     l = layoutManager,
			let     c = textContainer {
			for (index, zone) in zones.enumerated() {
				if  var note   = zone.note {
					if  index == 0 {
						note   = ZNote(zone)
						note.updatedRanges()
					}

					let  color = zone.color ?? kDefaultIdeaColor
					let offset = index == 0 ? 0 : (index == zones.count - 1) ? 2 : 1
					let  range = note.noteRange.offsetBy(offset)
					var   rect = l.boundingRect(forGlyphRange: range, in: c).offsetBy(dx: 15.5, dy: 8.0)
					rect .size = CGSize(width: 11.75, height: 15.0)

					dots.append(ZEssayDragDot(note: note, range: range, color: color, rect: rect))
				}
			}
		}

		return dots
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

	// MARK:- private
	// MARK:-

	func searchAgain(_ OPTION: Bool) {
	    let    seek = gSearching.searchText
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

	func dragDotHit(at rect: CGRect) -> ZEssayDragDot? {
		for dot in dragDots {
			if  dot.rect.intersects(rect) {
				return dot
			}
		}

		return nil
	}

	func attachmentHit(at rect: CGRect) -> ZRangedAttachment? {
		if  let array = textStorage?.rangedAttachments {
			for item in array {
				if  let imageRect = rectForRangedAttachment(item)?.insetEquallyBy(dotInset),
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
					let selectionRect = CGRect(origin: point, size: CGSize.zero).insetEquallyBy(dotInset)

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
			let            count = zone.countOfNotes
			gCreateCombinedEssay = current.isNote

			if  gCreateCombinedEssay {
				if  count > 1 {
					resetCurrentEssay(current)
				}
			} else if count > 0,
				let note = selectionZone?.currentNote {
				resetCurrentEssay(note)
			}
		}
	}

	func popNoteAndUpdate() {
		if  gRecents.pop() {
			exit()
		} else {
			updateText()
		}
	}

	private func convertToChild(createEssay: Bool = false) {
		if  let   text = selectionString, text.length > 0,
			let   dbID = gCurrentEssayZone?.databaseID,
			let parent = selectionZone {
			let  child = Zone.create(databaseID: dbID, named: text)   	// create new (to be child) zone from text

			insertText("", replacementRange: selectedRange)			// remove text
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

			insertText(replacement, replacementRange: selectedRange)
		}
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

	private func showSpecialCharactersPopup() {
		NSMenu.specialCharactersPopup(target: self, action: #selector(handleSymbolsPopupMenu(_:))).popUp(positioning: nil, at: selectionRect.origin, in: self)
	}

	@objc private func handleSymbolsPopupMenu(_ iItem: ZMenuItem) {
		if  let  type = ZSpecialCharactersMenuType(rawValue: iItem.keyEquivalent),
			type     != .eCancel {
			let  text = type.text

			insertText(text, replacementRange: selectedRange)
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
				case .hWeb:   link = gEssayController?.modalForHyperlink(textStorage?.string.substring(with: selectedRange))
				default:      if let b = gSelecting.pastableRecordName { link?.append(b) } else { return }
			}

			if  link == nil {
				textStorage?.removeAttribute(.link,               range: selectedRange)
			} else {
				textStorage?   .addAttribute(.link, value: link!, range: selectedRange)
			}
		}
	}

	var selectedNotes: [ZNote] {
		var array = [ZNote]()

		if  let zones = gCurrentEssayZone?.zonesWithNotes {
			for zone in zones {
				if  let note = zone.noteMaybe, note.noteRange.inclusiveIntersection(selectedRange) != nil {
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

	@discardableResult private func followCurrentLink(within range: NSRange) -> Bool {
		setSelectedRange(range)

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
								gControllers.swapMapAndEssay(force: .wMapMode)
								gRedrawMaps()
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

}

