//
//  ZEssay.swift
//  Seriously
//
//  Created by Jonathan Sand on 12/27/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

import Foundation

class ZEssay: ZNote {
	var      essayRange : NSRange { return NSRange(location: 0, length: essayLength) }
	override var   kind : String  { return "essay" }
	override var isNote : Bool    { return false }

	override var lastTextIsDefault: Bool {
		if  let last = progenyNotes.last,
			last    != self {
			return last.lastTextIsDefault
		}

		return true
	}

	override var lastTextRange: NSRange? {
		if  let    last = progenyNotes.last {
			return last.textRange.offsetBy(last.noteOffset)
		}

		return nil
	}

	override func readNoteTraits() -> NSMutableAttributedString? {
		if  let z = zone,
			(z.zoneProgenyWithVisibleNotes.count < 2 || !gCreateCombinedEssay) {

			// this is not an essay, convert it to a note

			z.clearAllNoteMaybes()

			gCreateCombinedEssay = false
			gCurrentEssay        = ZNote(z)
			essayText            = gCurrentEssay?.readNoteTrait()
		} else {
			updateProgenyNotes()

			essayText  = NSMutableAttributedString()
			var index  = progenyNotes.count
			let    max = index - 1
			if  index == 0 {

				// //////////////////////////// //
				// empty essay: convert to note //
				// //////////////////////////// //

				gCreateCombinedEssay = false
				let     note = ZNote(zone)

				if  let text = note.noteText {
					essayText?.insert(text, at: 0)
				}
			} else {
				gCreateCombinedEssay = true

				for note in progenyNotes.reversed() {
					index           -= 1

					note.updateIndentCount(relativeTo: zone)

					if  let  text = note.readNoteTrait() {
						essayText = essayText ?? NSMutableAttributedString()

						if  index < max {
							essayText?.insert(kNoteSeparator, at: 0)
						}

						essayText?    .insert(text,           at: 0)

						if  index > 0 {
							essayText?.insert(kNoteSeparator, at: 0)
							note.bumpLocations(by: kNoteSeparator.length)
						}
					}
				}

				updateNoteOffsets()
			}

			essayText?.fixAllAttributes()
		}

		essayLength = essayText?.length ?? 0

		return essayText
	}

	override func updateProgenyNotes() {
		progenyNotes.removeAll()

		if  let zones = zone?.zoneProgenyWithVisibleNotes {
			for z in zones {
				progenyNotes.append(ZNote(z))
			}
		}
	}

	override func updateNoteOffsets() {
		var offset = 0

		for note in progenyNotes {				// update note offsets
			note.noteOffset = offset
			offset         += note.textRange.upperBound + kNoteSeparator.length
		}
	}

	override func notes(in range: NSRange) -> ZNoteArray {
		var notes = ZNoteArray()

		for note in progenyNotes {
			if  range.inclusiveIntersection(note.noteRange) != nil {
				notes.append(note)
			}
		}

		return notes
	}

	override func isLocked(within range: NSRange) -> Bool {
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

	override func writeNoteTraits(_ attributedString: NSAttributedString?) {
		if  let attributed = attributedString {
			for note in progenyNotes {
				let range  = note.noteRange

				if  range.upperBound <= attributed.length {
					let substring = attributed.attributedSubstring(from: range)

					note.writeNoteTrait(substring)
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

		func examine(_ note: ZNote) {
			if  exact {
				adjust        -= note.noteRange.length

				note.zone?.deleteNote()
			} else {
				let (alter, delta) = note.shouldAlterNote(inRange: range, replacementLength: replacementLength, adjustment: adjust, hasReturn: hasReturn)

				if  alter     != .eLock {
					result     = .eAlter
					adjust    +=  delta

					if  alter == .eDelete {
						offset = note.noteOffset
					}
				}
			}
		}

		if  !hasProgenyNotes {
			examine(self)
		} else {
			for note in progenyNotes {
				examine(note)
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

		for note in progenyNotes {
		    updated = note.updateFontSize(increment) || updated
		}

		return updated
	}

}
