//
//  ZParagraph.swift
//  Zones
//
//  Created by Jonathan Sand on 12/27/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation

enum ZAlterationType: Int {
	case eAlter
	case eLock
	case eExit
}

class ZParagraph: NSObject {
	var partOffset = 0
	var  essayText : NSMutableAttributedString? { return paragraphText }
	var  partRange : NSRange { return NSRange(location: partOffset, length: textRange.upperBound) }
	var titleRange = NSRange ()
	var  textRange = NSRange ()
	var essayMaybe : ZTrait? { return zone?.traits[    .eEssay] }
	var essayTrait : ZTrait? { return zone?.trait(for: .eEssay) }
	var       zone : Zone?

	func delete() { zone?.removeTrait(for: .eEssay) }
	func saveEssay(_ attributedString: NSAttributedString?) { saveParagraph(attributedString) }
	func updateEssay(_ range: NSRange, length: Int) -> ZAlterationType { return updateParagraph(range, length: length) }

	init(_ zone: Zone?) {
		super.init()

		self.zone = zone
	}

	var titleAttributes: ZAttributesDictionary? {
		var result: ZAttributesDictionary?

		if	let      z = zone,
			let   font = ZFont(name: "Times-Roman", size: 36.0) {
			result     = [.font : font]

			if  z.colorized,
				let  c = z.color {
				result = [.font : font, .foregroundColor : c, .backgroundColor : c.lighter(by: 20.0)]
			}
		}

		return result
	}

	var paragraphText: NSMutableAttributedString? {
		var result:  NSMutableAttributedString?

		if  let   name = zone?.zoneName,
			let   text = essayTrait?.essayText {
			let spacer = "  "
			let  inset = spacer.length
			let offset = name.length + kBlankLine.length + (inset * 2)
			let  title = NSMutableAttributedString(string: spacer + name + spacer, attributes: titleAttributes)
			result     = NSMutableAttributedString()
			titleRange = NSRange(location: inset,  length: name.length)
			textRange  = NSRange(location: offset, length: text.length)

			result?.insert(text,       at: 0)
			result?.insert(kBlankLine, at: 0)
			result?.insert(title,      at: 0)
		}

		return result
	}

	func saveParagraph(_ attributedString: NSAttributedString?) {
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

	func updateParagraph(_ iRange: NSRange, length: Int) -> ZAlterationType {
		var 	result  		    	= ZAlterationType.eLock

		if  let range 		            = iRange.inclusiveIntersection(partRange)?.offsetBy(-partOffset) {
			if  range                  == partRange.offsetBy(-partOffset) {
				delete()
				gEssayEditor.swapGraphAndEssay()

				result					= .eExit
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
