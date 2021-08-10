//
//  ZEssay.swift
//  Seriously
//
//  Created by Jonathan Sand on 12/27/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

import Foundation

class ZEssay: ZNote {
	var essayRange: NSRange { return NSRange(location: 0, length: essayLength) }
	override var kind: String { return "essay" }

	override var lastTextIsDefault: Bool {
		if  let last = children.last,
			last    != self {
			return last.lastTextIsDefault
		}

		return true
	}

	override var lastTextRange: NSRange? {
		if  let    last = children.last {
			return last.textRange.offsetBy(last.noteOffset)
		}

		return nil
	}

	override var essayText: NSMutableAttributedString? {
		if  let z = zone,
			(z.zonesWithNotes.count < 2 || !gCreateCombinedEssay) {
			z.clearAllNotes()

			gCurrentEssay = ZNote(z)

			return noteText
		}

		gCreateCombinedEssay = true

		setupChildren()

		var result : NSMutableAttributedString?
		var index  = children.count
		let    max = index - 1

		if  index == 0 {    // empty essay
			let     note = ZNote(zone)

			if  let text = note.noteText {
				result?.insert(text, at: 0)
			}
		} else {
			for child in children.reversed() {
				index        -= 1
				let      bump = noteSeparator.length

				child.updateIndentCount(relativeTo: zone)

				if  let  text = child.noteText {
					result    = result ?? NSMutableAttributedString()

					if  index < max {
						result?.insert(noteSeparator, at: 0)
					}

					result?    .insert(text,       at: 0)

					if  index > 0 {
						result?.insert(noteSeparator, at: 0)
						child.bumpLocations(by: bump)
					}
				}
			}

			updateNoteOffsets()
		}

		essayLength = result?.length ?? 0

		result?.fixAllAttributes()

		return result
	}

	override func setupChildren() {
		children.removeAll()

		if  gCreateCombinedEssay {
			zone?.traverseAllProgeny { iChild in
				if  iChild.hasTrait(for: .tNote),
					let note = iChild.note,
					!self.children.contains(note) {
					self.children.append(note)	// do not use essayMaybe as it may not yet be initialized
				}
			}
		}
	}

	override func updateNoteOffsets() {
		var offset = 0

		for child in children {				// update note offsets
			child.noteOffset = offset
			offset           = child.offsetTextRange.upperBound + noteSeparator.length
		}
	}

	override func noteIn(_ range: NSRange) -> ZNote {
		for child in children {
			if  range.intersects(child.noteRange) {
				return child
			}
		}

		return self
	}

	override func isLocked(within range: NSRange) -> Bool {
		let     child = noteIn(range)
		let lockRange = range.offsetBy(-child.noteOffset)

		return (child == self) ? super.isLocked(within: range) : child.isLocked(within: lockRange)
	}

	override func injectIntoEssay(_ attributedString: NSAttributedString?) {
		if  let attributed  = attributedString {
			updatedRangesFrom(attributed)

			for child in children {
				let range   = child.noteRange

				if  range.upperBound <= attributed.length {
					let sub = attributed.attributedSubstring(from: range)

					child.injectIntoNote(sub)
				}
			}
		}

		gRelayoutMaps()
	}

	override func shouldAlterEssay(_ range:NSRange, replacementLength: Int) -> (ZAlterationType, Int) {
		let equal  = range.contains(essayRange)
		var result = ZAlterationType.eLock
		var adjust = 0
		var offset : Int?

		for child in children {
			if  equal {
				adjust        -= child.noteRange.length

				child.zone?.deleteNote()
			} else {
				let (alter,  delta) = child.shouldAlterNote(inRange: range, replacementLength: replacementLength, adjustment: adjust)

				if  alter     != .eLock {
					result     = .eAlter
					adjust    +=  delta

					if  alter == .eDelete {
						offset = child.noteOffset
					}
				}
			}
		}

		if  equal {
			result = .eExit
		} else if let o = offset {
			result = .eDelete
			adjust = o
		}

		return (result, adjust)
	}

	override func updateFontSize(_ increment: Bool) -> Bool {
		var updated = false

		for child in children {
		    updated = child.updateTraitFontSize(increment) || updated
		}

		return updated
	}

}
