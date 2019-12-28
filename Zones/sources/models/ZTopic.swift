//
//  ZEssay.swift
//  Zones
//
//  Created by Jonathan Sand on 12/27/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation

class ZTopic: NSObject {
	var titleRange = NSRange()
	var  textRange = NSRange()
	var       zone : Zone?

	init(_ zone: Zone?) {
		super.init()

		self.zone = zone
	}

	var topicText: NSMutableAttributedString? {
		var topic: NSMutableAttributedString?

		if  let   name = zone?.zoneName,
			let  color = zone?.color,
			let   text = zone?.trait(for: .eEssay).essayText,
			let   font = ZFont(name: "Times-Roman", size: 36.0) {
			let length = name.length + 2
			let  title = NSMutableAttributedString(string: name)
			let  blank = NSMutableAttributedString(string: "\n\n")
			titleRange = NSRange(location: 0, length: name.length)
			textRange  = NSRange(location: length, length: text.length)
			let  range = NSRange(location: 0, length: length)
			topic      = NSMutableAttributedString()

			topic?.append(title)
			topic?.append(blank)
			topic?.append(text)
			topic?.addAttributes([.font:font, .foregroundColor:color], range: range)
		}

		return topic
	}

	func save(_ attributedString: NSAttributedString?) {
		if  let  attributed = attributedString,
			let       essay = zone?.trait(for: .eEssay) {
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

	func frozen(_ range:NSRange) -> Bool {
		return (range.location > titleRange.upperBound && range.location   < textRange.location) ||
			(range.upperBound  > titleRange.upperBound && range.upperBound < textRange.location) ||
			(range.location    < titleRange.upperBound && range.upperBound > textRange.lowerBound)
	}

	func update(_ range:NSRange, _ length: Int) -> Bool {
		var altered = false

		if !frozen(range) {
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

		return altered
	}

}
