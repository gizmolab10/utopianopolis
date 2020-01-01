//
//  ZEssayPart.swift
//  Zones
//
//  Created by Jonathan Sand on 12/27/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation

enum ZAlterationType: Int {
	case eDelete
	case eAlter
	case eLock
}

class ZEssayPart: NSObject {
	var partOffset = 0
	var  essayText : NSMutableAttributedString? { return partialText }
	var  partRange : NSRange { return NSRange(location: partOffset, length: textRange.upperBound) }
	var titleRange = NSRange ()
	var  textRange = NSRange ()
	var essayMaybe : ZTrait? { return zone?.traits[    .eEssay] }
	var essayTrait : ZTrait? { return zone?.trait(for: .eEssay) }
	var       zone : Zone?

	func delete() { zone?.removeTrait(for: .eEssay) }
	func saveEssay(_ attributedString: NSAttributedString?) { savePart(attributedString) }
	func updateEssay(_ range: NSRange, length: Int) -> ZAlterationType { return updatePart(range, length: length) }

	init(_ zone: Zone?) {
		super.init()

		self.zone = zone
	}

	var partialText: NSMutableAttributedString? {
		var result:  NSMutableAttributedString?

		if  let   name = zone?.zoneName,
			let  color = zone?.color,
			let   text = essayTrait?.essayText,
			let   font = ZFont(name: "Times-Roman", size: 36.0) {
			let offset = name.length + 2
			let  title = NSMutableAttributedString(string: name, attributes: [.font:font, .foregroundColor:color])
			titleRange = NSRange(location: 0,      length: name.length)
			textRange  = NSRange(location: offset, length: text.length)
			result     = NSMutableAttributedString()

			result?.insert(title,      at: 0)
			result?.insert(kBlankLine, at: result!.length)
			result?.insert(text,       at: result!.length)
		}

		return result
	}

	func savePart(_ attributedString: NSAttributedString?) {
		if  let  attributed = attributedString,
			let       essay = essayMaybe {
			let      string = attributed.string
			let        text = attributed.attributedSubstring(from: textRange)
			let       title = string.substring(with: titleRange).replacingOccurrences(of: "\n", with: "")
			essay.essayText = text.mutableCopy() as? NSMutableAttributedString
			zone? .zoneName = title

			zone?.needSave()
			essay.needSave()
		}
	}

	func isLocked(for range: NSRange) -> Bool {
		return
			(range.lowerBound > titleRange.upperBound && range.lowerBound <  textRange.lowerBound) ||
			(range.upperBound > titleRange.upperBound && range.upperBound <  textRange.lowerBound) ||
			(range.lowerBound < titleRange.upperBound && range.upperBound >= textRange.lowerBound)
	}

	func updatePart(_ iRange: NSRange, length: Int) -> ZAlterationType {
		var 	result  		    	= ZAlterationType.eLock

		if  let range 		            = iRange.inclusiveIntersection(partRange)?.offsetBy(-partOffset) {
			if  range                  == partRange {
				delete()
				gEssayEditor.swapGraphAndEssay()

				result					= .eDelete
			} else if !isLocked(for: range) {
				if  let    intersection = range.inclusiveIntersection(textRange) {
					textRange  .length += length - intersection.length
					result              = .eAlter
				}

				if  let    intersection = range.inclusiveIntersection(titleRange) {
					let delta           = length - intersection.length
					titleRange .length += delta
					textRange.location += delta
					result              = .eAlter
				}
			}
		}

		return 	result
	}

}
