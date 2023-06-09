//
//  ZEssayControlsView.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/6/22.
//  Copyright © 2022 Zones. All rights reserved.
//

import Foundation

class ZEssayControlsView: ZView {
	var       isTitlesControlDark = false
	var            inspectorBar   : ZView?   { return gMainWindow?.inspectorBar }
	@IBOutlet var  titlesControl  : ZSegmentedControl?
	@IBOutlet var  cancelButton   : ZHoverableButton?
	@IBOutlet var  deleteButton   : ZHoverableButton?
	@IBOutlet var  printButton    : ZHoverableButton?
	@IBOutlet var  hideButton     : ZHoverableButton?
	@IBOutlet var  saveButton     : ZHoverableButton?
	@IBAction func handleEssayControlClicked(_ button: ZHoverableButton) { gEssayView?.essayActionFor(button) }

	func setupEssayControls() {
		if  let           b = inspectorBar, !b.subviews.contains(self) {
			var        rect = bounds
			let           x = b.maxX + 4.0
			rect    .origin = CGPoint(x: x, y: 6.0)
			rect.size.width = 100.0
			frame           = rect

			b.addSubview(self)
		}
	}

	func enableEssayControls(_ enabled: Bool) {
		deleteButton?.setEnabledAndTracking(enabled)
		cancelButton?.setEnabledAndTracking(enabled)
		printButton? .setEnabledAndTracking(enabled)
		hideButton?  .setEnabledAndTracking(enabled)
		saveButton?  .setEnabledAndTracking(enabled)

		updateTitleSegments(enabled)
	}

	// MARK: - titles control
	// MARK: -

	func updateTitleSegments(_ enabled: Bool = true) {
		let                  isNote = gCurrentEssay?.isNote ?? true
		let                  invert = isTitlesControlDark != gIsDark
		let                segments = isNote ? 2 : 3
		titlesControl?.segmentCount = segments
		titlesControl?   .isEnabled = enabled
		isTitlesControlDark         = gIsDark

		if !isNote {
			var   image = kShowDragDot
			image?.size = CGSize.squared(16.0)

			if  gIsDark {
				image   = image?.invertedImage
			}

			titlesControl?.setToolTip("show titles and drag dots", forSegment: 2)
			titlesControl?.setImage(image,                         forSegment: 2)
		}

		for segment in 0..<segments {
			if  var        image = titlesControl?.image(forSegment: segment) {
				image.isTemplate = true

				if  invert,
					let inverted = image.invertedImage {
					image        = inverted
				}

				titlesControl?.setImage(image,          forSegment: segment)

			}
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

		return deltaWithTransitionTo(mode)  // updates gEssayTitleMode
	}

	func titleLengthsUpTo(_ note: ZNote, for mode: ZEssayTitleMode) -> Int {
		let    isEmpty = mode == .sEmpty
		let     isFull = mode == .sFull
		if  let  eZone = gCurrentEssay?.zone,  // essay zones
			let target = note.zone {           // target zone
			let eZones = eZone.zoneProgenyWithVisibleNotes
			let  isOne = eZones.count == 1
			var  total = isOne ? -4 : isEmpty ? -2 : isFull ? -2 : 0

			for zone in eZones {
				if  let note = zone.note {
					note.updateIndentCount(relativeTo: eZone)

					total += note.titleOffsetFor(mode)
				}

				if  zone  == target {
					return total
				}
			}
		}

		return isEmpty ? 0 : note.titleRange.length
	}

	func deltaWithTransitionTo(_ mode: ZEssayTitleMode) -> Int {
		var delta           = 0
		if  mode           != gEssayTitleMode {
			if  let    note = gEssayView?.selectedNote {
				let  before = titleLengthsUpTo(note, for: gEssayTitleMode) // call this first
				let   after = titleLengthsUpTo(note, for: mode)            // call this second
				delta       = after - before
			}

			gEssayTitleMode = mode
		}

		return delta
	}

	@IBAction func handleSegmentedControlAction(_ iControl: ZSegmentedControl) {
		if  let  mode = ZEssayTitleMode(rawValue: iControl.selectedSegment) {
			var range = gEssayView?.selectedRange ?? NSRange()

			if  mode != gEssayTitleMode { // user is changing mode
				gCurrentEssay?.updatedRangesFrom(gEssayView?.textStorage)
			}

			gEssayView?.writeViewToTraits()

			range.location += deltaWithTransitionTo(mode)
			titlesControl?.needsDisplay = true

			gEssayView?.readTraitsIntoViewRestoringSelection(range)
			gDispatchSignals([.sEssay])
		}
	}

}

enum ZEssayTitleMode: Int {
	case sEmpty // do not change the order, storyboard and code dependencies
	case sTitle
	case sFull
}

enum ZEssayButtonID : Int {
	case idForward
	case idDiscard
	case idDelete
	case idTitles
	case idPrint
	case idBack
	case idSave
	case idHide

	static var all: [ZEssayButtonID] { return [.idBack, .idForward, .idSave, .idPrint, .idHide, .idDelete, .idDiscard] } // , .idMultiple] }

	static func essayID(for button: ZHoverableButton) -> ZEssayButtonID? {
		if  let i = gConvertFromOptionalUserInterfaceItemIdentifier(button.identifier) {
			switch i {
				case "left.arrow":  return .idBack
				case "right.arrow": return .idForward
				case "discard":     return .idDiscard
				case "trash":       return .idDelete
				case "printer":     return .idPrint
				case "exit":        return .idHide
				case "save":        return .idSave
				default: break
			}
		}

		return nil
	}

}
