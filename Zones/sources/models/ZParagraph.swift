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
	var paragraphOffset = 0
	var     essayLength = 0
	var     essayMaybe  : ZTrait?  { return zone?.traits[    .eEssay] }
	var     essayTrait  : ZTrait?  { return zone?.trait(for: .eEssay) }
	var     zone        : Zone?
	var  paragraphRange : NSRange  { return NSRange(location: paragraphOffset, length: textRange.upperBound) }
	var  fullTitleRange : NSRange  { var range = titleRange; range.location += paragraphOffset - 2; range.length += 3; return range }
	var   lastTextRange : NSRange? { return textRange }
	var      titleRange = NSRange()
	var       textRange = NSRange()

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
			let offset = NSNumber(floatLiteral: Double(gEssayTitleFontSize) / 7.0)
			result     = [.font : gEssayTitleFont, .paragraphStyle : paragraphStyle, .baselineOffset : offset]

			if  z.colorized,
				let  c = z.color {
				result?[.foregroundColor] = c
			}
		}

		return result
	}

	var essayText : NSMutableAttributedString? {
		let    result = paragraphText

		if  let     z = zone, z.colorized,
			let color = z.color?.lighter(by: 20.0) {

			result?.addAttribute(.backgroundColor, value: color, range: fullTitleRange)
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

			result?.fixAllAttributes()
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

	func updateParagraph(_ iRange: NSRange, length: Int, adjustment: Int = 0) -> (ZAlterationType, Int) {
		var 	result  		    	= ZAlterationType.eLock
		var      delta                  = 0

		if  let range 		            = iRange.inclusiveIntersection(paragraphRange)?.offsetBy(-paragraphOffset) {
			if  range                  == paragraphRange.offsetBy(-paragraphOffset) {
				result					= .eDelete

				delete()
			} else if !isLocked(for: range) {
				if  let    intersection = range.inclusiveIntersection(textRange) {
					delta               = length - intersection.length
					textRange  .length += delta
					result              = .eAlter
				}

				if  let    intersection = range.inclusiveIntersection(titleRange) {
					delta               = length - intersection.length
					titleRange .length += delta
					textRange.location += delta
					result              = .eAlter
				}
			}
		}

		paragraphOffset += adjustment

		return 	(result, delta)
	}

	func updateEssay(_ range: NSRange, length: Int) -> (ZAlterationType, Int) {
		var (result, delta) = updateParagraph(range, length: length)

		if  result == .eDelete {
			result  = .eExit
		}

		return (result, delta)
	}

}
