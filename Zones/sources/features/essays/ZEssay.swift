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
	var    essayRange : NSRange { return NSRange(location: 0, length: essayLength) }
	override var kind : String  { return "essay" }

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
			(z.zonesWithVisibleNotes.count < 2 || !gCreateCombinedEssay) {

			// this is not an essay, convert it to a note

			z.clearAllNotes()

			gCreateCombinedEssay = false
			gCurrentEssay = ZNote(z)

			return gCurrentEssay?.noteText
		}

		setupChildNotes()

		var result : NSMutableAttributedString?
		var index  = children.count
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

			for child in children.reversed() {
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

	override func setupChildren() {
		children.removeAll()

		if  gCreateCombinedEssay {
			setupChildNotes()
		}
	}

	func setupChildNotes() {
		children.removeAll()
		if  let zones = zone?.zonesWithVisibleNotes {
			children  = zones.map { return $0.note! }
		}
	}

	override func updateNoteOffsets() {
		var offset = 0

		for child in children {				// update note offsets
			child.noteOffset = offset
			offset          += child.textRange.upperBound + kNoteSeparator.length
		}
	}

	override func notes(in range: NSRange) -> [ZNote] {
		var result = [ZNote]()
		for child in children {
			if  range.intersects(child.noteRange) {
				result.append(child)
			}
		}

		return result
	}

	override func isLocked(within range: NSRange) -> Bool {
		let notes = notes(in: range)

		for note in notes {
			if  note.zone == zone,
				super.isLocked(within: range) {
				return true
			} else {
				let lockRange = range.offsetBy(-note.noteOffset)

				if note.isLocked(within: lockRange) {
					return true
				}
			}
		}

		return false
	}

	override func saveAsEssay(_ attributedString: NSAttributedString?) {
		if  let attributed = attributedString {
			for child in children {
				let range  = child.noteRange

				if  range.upperBound <= attributed.length {
					let substring = attributed.attributedSubstring(from: range)

					child.saveAsNote(substring)
				}
			}
		}

		gRelayoutMaps()
	}

	override func shouldAlterEssay(in range: NSRange, replacementLength: Int) -> (ZAlterationType, Int) {
		let inside = range.contains(essayRange)
		var result = ZAlterationType.eLock
		var adjust = 0
		var offset : Int?

		let examine = { (note: ZNote) in
			if  inside {
				adjust        -= note.noteRange.length

				note.zone?.deleteNote()
			} else {
				let (alter,  delta) = note.shouldAlterNote(inRange: range, replacementLength: replacementLength, adjustment: adjust)

				if  alter     != .eLock {
					result     = .eAlter
					adjust    +=  delta

					if  alter == .eDelete {
						offset = note.noteOffset
					}
				}
			}
		}

		if  children.count == 0 {
			examine(self)
		} else {
			for child in children {
				examine(child)
			}
		}

		if  inside {
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
