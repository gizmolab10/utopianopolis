//
//  ZEssay.swift
//  Zones
//
//  Created by Jonathan Sand on 12/27/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation

class ZEssay: ZParagraph {
	var children = [ZParagraph]()

	func setupChildren() {
		if  gCreateMultipleEssay {
			zone?.traverseAllProgeny {   iChild in
				if  iChild.hasTrait(for: .eEssay) {
					self.children.append(iChild.essay)
				}
			}
		}
	}

	override var essayText: NSMutableAttributedString? {
		var result: NSMutableAttributedString?
		var count  = children.count

		if  count == 0 {    // the first time
			let        e = ZParagraph(zone)

			if  let text = e.paragraphText {
				result?.insert(text, at: 0)
			}
		} else {
			for child in children.reversed() {
				count         -= 1

				if  let   text = child.paragraphText {
					result     = result ?? NSMutableAttributedString()
					result?.insert(gBlankLine, at: 0)
					result?.insert(text,       at: 0)
				}
			}

			var offset = 0

			for child in children {	// update essayIndices
				child.partOffset = offset
				offset          += child.textRange.upperBound + gBlankLine.length
			}
		}

		return result
	}

	override func saveEssay(_ attributedString: NSAttributedString?) {
		if  let  attributed = attributedString {
			for child in children {
				let range   = child.partRange

				if  range.upperBound <= attributed.length {
					let sub = attributed.attributedSubstring(from: range)

					child.saveParagraph(sub)
				}
			}
		}
	}

	override func updateEssay(_ range:NSRange, length: Int) -> ZAlterationType {
		var result = ZAlterationType.eLock
		let equal  = range.inclusiveIntersection(partRange) == partRange

		for child in children {
			if  equal {
				child.delete()
			} else {
				let alter  = child.updateParagraph(range, length: length)

				if  alter != .eLock {
					result = .eAlter
				}
			}
		}

		if  equal {
			result = .eExit
		}

		return 	result
	}

	override func updateFontSize(_ increment: Bool) -> Bool {
		var updated = false

		for child in children {
		    updated = child.updateTraitFontSize(increment) || updated
		}

		return updated
	}

}
