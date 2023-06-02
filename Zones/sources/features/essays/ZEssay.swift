//
//  ZEssay.swift
//  Seriously
//
//  Created by Jonathan Sand on 12/27/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

import Foundation

func gCreateEssay(_ zone: Zone) -> ZEssay {
	return ZEssay(zone)
}

class ZEssay: ZNote {
	var         essayRange : NSRange { return NSRange(location: 0, length: essayLength) }
	override var      kind : String  { return "essay" }
	override var firstNote : ZNote   { return childrenNotes.count == 0 ? self : childrenNotes[0] }

	override var lastTextIsDefault: Bool {
		if  let last = childrenNotes.last,
			last    != self {
			return last.lastTextIsDefault
		}

		return true
	}

	override var lastTextRange: NSRange? {
		if  let    last = childrenNotes.last {
			return last.textRange.offsetBy(last.noteOffset)
		}

		return nil
	}

	override var essayText: NSMutableAttributedString? {
		if  let z = zone,
			(z.zonesWithVisibleNotes.count < 2 || !gCreateCombinedEssay) {

			// this is not an essay, convert it to a note

			z.clearAllNoteMaybes()

			gCreateCombinedEssay = false
			gCurrentEssay = ZNote(z)

			return gCurrentEssay?.noteText
		}

		updateChildren()

		var result : NSMutableAttributedString?
		var index  = childrenNotes.count
		let    max = index - 1

		if  index == 0 {

			// //////////////////////////// //
			// empty essay: convert to note //
			// //////////////////////////// //

			gCreateCombinedEssay = false
			let     note = ZNote(zone)

			if  let text = note.noteText {
				result?.insert(text, at: 0)
			}
		} else {
			gCreateCombinedEssay = true

			for child in childrenNotes.reversed() {
				index           -= 1

				child.updateIndentCount(relativeTo: zone)

				if  let  text = child.noteText {
					result    = result ?? NSMutableAttributedString()

					if  index < max {
						result?.insert(kNoteSeparator, at: 0)
					}

					result?    .insert(text,           at: 0)

					if  index > 0 {
						result?.insert(kNoteSeparator, at: 0)
						child.bumpLocations(by: kNoteSeparator.length)
					}
				}
			}

			updateNoteOffsets()
		}

		essayLength = result?.length ?? 0

		result?.fixAllAttributes()

		return result
	}

	override func updateChildren() {
		childrenNotes.removeAll()

		if  let     zones = zone?.zonesWithVisibleNotes {
			childrenNotes = zones.filter { $0.createNoteMaybe(onlyTheNote: false) != nil }.map { $0.noteMaybe! }
		}
	}

	override func updateNoteOffsets() {
		var offset = 0

		for child in childrenNotes {				// update note offsets
			let        note = child.firstNote
			note.noteOffset = offset
			offset         += note.textRange.upperBound + kNoteSeparator.length
		}
	}

	override func notes(in range: NSRange) -> ZNoteArray {
		var result = ZNoteArray()

		updateChildren()              // needed when a note is created...
		updateNoteOffsets()           // ...in a parent whose children have notes

		for child in childrenNotes + [self] {
			if  range.inclusiveIntersection(child.noteRange) != nil {
				result.append(child)
			}
		}

		return result
	}

	override func isLocked(within range: NSRange) -> Bool {
		updateNoteOffsets()

		for note in notes(in: range) {
			if  note.zone != zone {
				let lockRange = range.offsetBy(-note.noteOffset)

				if  note.isLocked(within: lockRange) {
					return true
				}
			} else if  super.isLocked(within: range) {
				return true
			}
		}

		return false
	}

	override func saveAsEssay(_ attributedString: NSAttributedString?) {
		if  let attributed = attributedString {
			for child in childrenNotes {
				let range  = child.noteRange

				if  range.upperBound <= attributed.length {
					let substring = attributed.attributedSubstring(from: range)

					child.saveAsNote(substring)
				}
			}

			needsSave = false
		}
	}

	override func shouldAlterEssay(in range: NSRange, replacementLength: Int, hasReturn: Bool = false) -> (ZAlterationType, Int) {
		let  exact = range.inclusiveIntersection(essayRange) == essayRange
		var result = ZAlterationType.eLock
		var adjust = 0
		var offset : Int?

		let examine = { (note: ZNote) in
			if  exact {
				adjust        -= note.noteRange.length

				note.zone?.deleteNote()
			} else {
				let (alter,  delta) = note.shouldAlterNote(inRange: range, replacementLength: replacementLength, adjustment: adjust, hasReturn: hasReturn)

				if  alter     != .eLock {
					result     = .eAlter
					adjust    +=  delta

					if  alter == .eDelete {
						offset = note.noteOffset
					}
				}
			}
		}

		if  childrenNotes.count == 0 {
			examine(self)
		} else {
			for child in childrenNotes {
				examine(child)
			}
		}

		if  exact {
			result = .eExit
		} else if let o = offset {
			result = .eDelete
			adjust = o
		}

		return (result, adjust)
	}

	override func updateFontSize(_ increment: Bool) -> Bool {
		var updated = false

		for  in childrenNotes {
		    updated = note.updateTraitFontSize(increment) || updated
		}

		return updated
	}

}
