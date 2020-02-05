//
//  ZEssay.swift
//  Zones
//
//  Created by Jonathan Sand on 12/27/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation

class ZEssay: ZParagraph {
	var essayRange: NSRange { return NSRange(location: 0, length: essayLength) }
	override var lastTextIsDefault: Bool { return children.last?.lastTextIsDefault ?? false }

	override var lastTextRange: NSRange? {
		if  let    last = children.last {
			return last.textRange.offsetBy(last.paragraphOffset)
		}

		return nil
	}

	override var essayText: NSMutableAttributedString? {
		var result: NSMutableAttributedString?
		var index  = children.count

		if  index == 0 {    // the first time
			let paragraph = ZParagraph(zone)

			if  let  text = paragraph.paragraphText {
				result?.insert(text, at: 0)
			}
		} else {
			for child in children.reversed() {
				index        -= 1
				let 	 bump = gBlankLine.length

				if  let  text = child.paragraphText {
					result    = result ?? NSMutableAttributedString()
					result?.insert(gBlankLine, at: 0)
					result?.insert(text,       at: 0)

					if  index > 0 {
						result?.insert(gBlankLine, at: 0)
						child.bumpOffsets(by: bump)
					}
				}
			}

			for child in children {
				child.colorize(result)
			}

			updateOffsets()
		}

		essayLength = result?.length ?? 0

		result?.fixAllAttributes()

		return result
	}

	override func setupChildren() {
		if  gCreateMultipleEssay {
			children.removeAll()

			zone?.traverseAllProgeny { iChild in
				if  iChild.hasTrait(for: .eEssay) {
					let essay = iChild.essay

					if !self.children.contains(essay) {
						self.children.append(essay)	// do not use essayMaybe as it may not yet be initialized
					}
				}
			}
		}
	}

	override func updateOffsets() {
		var offset = 0

		for child in children {				// update paragraph offsets
			child.paragraphOffset = offset
			offset                = child.offsetTextRange.upperBound + gBlankLine.length
		}
	}

	override func saveEssay(_ attributedString: NSAttributedString?) {
		if  let attributed  = attributedString {
			for child in children {
				let range   = child.paragraphRange

				if  range.upperBound <= attributed.length {
					let sub = attributed.attributedSubstring(from: range)

					child.saveParagraph(sub)
				}
			}
		}

		gControllers.redrawAndSync()
	}

	override func shouldAlterEssay(_ range:NSRange, length: Int) -> (ZAlterationType, Int) {
		let equal  = range.inclusiveIntersection(essayRange) == essayRange
		var result = ZAlterationType.eLock
		var adjust = 0
		var offset : Int?

		for child in children {
			if  equal {
				adjust    -= child.paragraphRange.length

				child.delete()
			} else {
				let (alter,  delta) = child.shouldAlterParagraph(range, length: length, adjustment: adjust)
				adjust    += delta

				if  alter != .eLock {
					result = .eAlter

					if  alter == .eDelete {
						offset = child.paragraphOffset
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
