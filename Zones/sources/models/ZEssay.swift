//
//  ZEssay.swift
//  Zones
//
//  Created by Jonathan Sand on 12/27/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation

class ZEssay: ZEssayPart {
	var children = [ZEssayPart]()

	func setupChildren() {
		zone?.traverseAllProgeny {   iChild in
			if  iChild.hasTrait(for: .eEssay) {
				self.children.append(iChild.essay)
			}
		}
	}

	override var essayText: NSMutableAttributedString? {
		var result: NSMutableAttributedString?
		var count  = children.count
		var offset = 0

		for child in children.reversed() {
			count         -= 1

			if  let   text = child.partialText {
				result     = result ?? NSMutableAttributedString()
				result?.insert(text, at: 0)

				if  count != 0 {
					result?.insert(kBlankLine, at: 0)
				}
			}
		}

		if  result == nil {    // detect when no partial text has been added
			let   e = ZEssayPart(zone)

			if  let text = e.partialText {
				result?.insert(text, at: 0)
			}
		}

		for child in children {	// update essayIndices
			child.partOffset = offset
			offset          += child.textRange.upperBound
		}

		return result
	}

	override func save(_ attributedString: NSAttributedString?) {
		if  let  attributed = attributedString {
			for child in children {
				let range   = child.partRange

				if  range.upperBound <= attributed.length {
					let sub = attributed.attributedSubstring(from: range)

					child.savePart(sub)
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
				let alter  = child.updatePart(range, length: length)

				if  alter == .eAlter {
					result = .eAlter
				}
			}
		}

		if  equal {
			result = .eDelete
			gEssayEditor.swapGraphAndEssay()
		}

		return 	result
	}

}
