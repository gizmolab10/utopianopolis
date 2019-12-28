//
//  ZEssay.swift
//  Zones
//
//  Created by Jonathan Sand on 12/27/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation

class ZEssay: NSObject {
	var essayIndex = 0
	var titleRange = NSRange()
	var  textRange = NSRange()
	var essayRange : NSRange { return NSRange(location: titleRange.location, length: textRange.upperBound) }
	var      trait : ZTrait? { return zone?.trait(for: .eEssay) }
	var       zone : Zone?
	func delete() { zone?.removeTrait(for: .eEssay) }

	init(_ zone: Zone?) {
		super.init()

		self.zone = zone
	}

	var essayText: NSMutableAttributedString? {
		var essay: NSMutableAttributedString?

		if  let   name = zone?.zoneName,
			let  color = zone?.color,
			let   text = trait?.essayText,
			let   font = ZFont(name: "Times-Roman", size: 36.0) {
			let length = name.length + 2
			let  title = NSMutableAttributedString(string: name, attributes: [.font:font, .foregroundColor:color])
			let  blank = NSMutableAttributedString(string: "\n\n")
			titleRange = NSRange(location: 0, length: name.length)
			textRange  = NSRange(location: length, length: text.length)
			essay      = NSMutableAttributedString()

			essay?.insert(text,  at: 0)
			essay?.insert(blank, at: 0)
			essay?.insert(title, at: 0)
		}

		return essay
	}

	func save(_ attributedString: NSAttributedString?) {
		if  let  attributed = attributedString,
			let       essay = zone?.traits[.eEssay] {
			let      string = attributed.string
			let        text = attributed.attributedSubstring(from: textRange)
			let       title = string.substring(with: titleRange).replacingOccurrences(of: "\n", with: "")
			essay.essayText = text.mutableCopy() as? NSMutableAttributedString
			zone? .zoneName = title

			zone?.needSave()
			essay.needSave()
			gControllers.signalFor(zone, multiple: [.eDatum])
		}
	}

	func intersectsLocked(_ range:NSRange) -> Bool {
		return
			(range.location    > titleRange.upperBound && range.location   <  textRange.location) ||
			(range.upperBound  > titleRange.upperBound && range.upperBound <  textRange.location) ||
			(range.location    < titleRange.upperBound && range.upperBound >= textRange.lowerBound)
	}

	func update(_ range:NSRange, length: Int) -> Bool {
		var 	altered 			= false

		if !intersectsLocked(range) {
			if  let    intersection = range.inclusiveIntersection(textRange) {
				textRange  .length += length - intersection.length
				altered             = true
			}

			if  let    intersection = range.inclusiveIntersection(titleRange) {
				let delta           = length - intersection.length
				titleRange .length += delta
				textRange.location += delta
				altered             = true
			}
		}

		return 	altered
	}

}
