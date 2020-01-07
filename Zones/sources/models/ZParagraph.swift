//
//  ZParagraph.swift
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
	func updateFontSize(_ increment: Bool) -> Bool { return updateTraitFontSize(increment) }
	func updateTraitFontSize(_ increment: Bool) -> Bool { return essayTrait?.updateEssayFontSize(increment) ?? false }

	init(_ zone: Zone?) {
		super.init()

		self.zone = zone
	}

	var paragraphStyle: NSMutableParagraphStyle {
		let tabStop = NSTextTab(textAlignment: .right, location: 6000.0, options: [:])
		let paragraph = NSMutableParagraphStyle()
		paragraph.tabStops = [tabStop]

		return paragraph
	}

	var titleAttributes: ZAttributesDictionary? {
		var result: ZAttributesDictionary?

		if	let      z = zone {
			result     = [.font : gEssayTitleFont, .paragraphStyle : paragraphStyle]

			if  z.colorized,
				let  c = z.color {
				result = [.font : gEssayTitleFont, .paragraphStyle : paragraphStyle, .foregroundColor : c, .backgroundColor : c.lighter(by: 20.0)]
			}
		}

		return result
	}

	var paragraphText: NSMutableAttributedString? {
		var result:  NSMutableAttributedString?

		if  let    name = zone?.zoneName,
			let    text = essayTrait?.essayText {
			let  spacer = "  "
			let tOffset = spacer.length + gBlankLine.length
			let pOffset = tOffset + name.length + gBlankLine.length + 1
			let   title = NSMutableAttributedString(string: spacer + name + kTab, attributes: titleAttributes)
			result      = NSMutableAttributedString()
			titleRange  = NSRange(location: tOffset, length: name.length)
			textRange   = NSRange(location: pOffset, length: text.length)

			result?.insert(text,       at: 0)
			result?.insert(gBlankLine, at: 0)
			result?.insert(title,      at: 0)
			result?.insert(gBlankLine, at: 0)
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
				result					= .eDelete

				delete()
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

	func updateEssay(_ range: NSRange, length: Int) -> ZAlterationType {
		let result  = updateParagraph(range, length: length)

		if  result == .eDelete {
			return .eExit
		}

		return result
	}

}
