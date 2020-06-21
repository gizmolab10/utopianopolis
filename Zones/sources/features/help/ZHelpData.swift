//
//  ZHelpData.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/9/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZHelpData: NSObject {

	var helpMode          = ZHelpMode.noMode
	var tabStops          = [NSTextTab]()
	var noTabPrefix       :   String   { return "   " }
	var columnStrings     : [[String]] { return [[]] }
	var tabOffsets        :   [Int]    { return [0, 20, 85] } // default for graph shortcuts
	var columnWidth       :    Int     { return 290 }         // "
	var indexOfLastColumn :    Int     { return 3 }           // "
	var stringsPerRow     :    Int     { return 3 }
	var isPro             :    Bool    { return gCurrentHelpMode == .allMode }
	var boldFont          :    ZFont   { return kBoldFont }

	func dotTypes(for row: Int, column: Int) -> (ZHelpDotType?, ZFillType?) { return (nil, nil) }

	var countOfRows : Int {
		var result = 0

		for array in columnStrings {
			result = max(result, array.count)
		}

		return result / stringsPerRow
	}

	var rowHeight : CGFloat { return 17.0 }

	func setup(for iMode: ZHelpMode) {
		helpMode   = iMode
		var offset = 0
		var values : [Int] = []

		for _ in 0...indexOfLastColumn {
			for index in 0..<stringsPerRow {
				values.append(offset + tabOffsets[index])
			}

			offset += columnWidth
		}

		for     value in values {
			if  value != 0 {
				tabStops.append(NSTextTab(textAlignment: .left, location: CGFloat(value), options: [:]))
			}
		}
	}

	func objectValueFor(_ row: Int) -> NSMutableAttributedString {
		let         result = NSMutableAttributedString()
		let      paragraph = NSMutableParagraphStyle()
		paragraph.tabStops = tabStops

		for column in 0...indexOfLastColumn {
			let a = attributedString(for: row, column: column)

			result.append(a)
		}

		result.addAttribute(.paragraphStyle, value: paragraph as Any, range: NSMakeRange(0, result.length))

		return result
	}

	func strings(for row: Int, column: Int) -> (String, String, String) {
		let strings = strippedStrings(for: column)
		let   index = row * stringsPerRow

		return index >= strings.count ? ("", "", "") : (strings[index], strings[index + 1], strings[index + 2])
	}

	func strippedStrings(for column: Int) -> [String] {
		var        result = [String]()

		if  column < 0 {
			return result
		}

		let    rawStrings = columnStrings[column]
		let         count = rawStrings.count / stringsPerRow
		var         index = 0

		while    index < count {
			let offset = index * stringsPerRow
			let  first = rawStrings[offset]
			let second = rawStrings[offset + 1]
			let  third = rawStrings[offset + 2]
			let   type = ZHelpType(rawValue: first.substring(with: NSMakeRange(0, 1))) // grab first character
			index     += 1

			if      isPro || type != .hPro {
				if  isPro || type != .hInsert {
					result.append(first)
					result.append(second)
					result.append(third)
				} else {
					while result.count < 90 {
						result.append("")
					}
				}
			}
		}

		return result
	}

	func attributedString(for row: Int, column: Int) -> NSMutableAttributedString {
		var (first, second, url) = strings(for: row, column: column)
		let     rawChar = first.substring(with: NSMakeRange(0, 1))
		let       lower = rawChar.lowercased()
		let       SHIFT = lower != rawChar
		let        type = ZHelpType(rawValue: lower) // grab first character
		let     command = first.substring(fromInclusive: 1)             // grab remaining characters
		var  attributes = ZAttributesDictionary ()
		let      hasURL = !url.isEmpty
		var      prefix = "   "

		switch gCurrentHelpMode {
			case .dotMode: attributes[.font] = kLargeHelpFont
			default:       attributes[.font] = nil
		}

		if !isPro && (SHIFT || type == .hPro) {
			return NSMutableAttributedString(string: kTab + kTab + kTab)
		}

		switch type {
			case .hDots?:
				prefix = noTabPrefix
			case .hBold?:
				attributes[.font] = boldFont
			case .hAppend?, .hUnderline?:
				attributes[.underlineStyle] = 1
			case .hPlain?, .hPro?:
				if  hasURL {
					attributes[.foregroundColor] = gHelpHyperlinkColor

					if !url.isHyphen {
						second.append(kSpace + kEllipsis)
					}
				}

				fallthrough

			default:
				prefix = kTab		// for empty lines, including after last row
		}

		let result = NSMutableAttributedString(string: prefix)

		switch type {
			case .hDots?:
				break
			case .hPlain?:
				result.append(NSAttributedString(string: command))
			default:
				if  isPro,
					type == .hPro {
					second = "** " + second
				}

				result.append(NSAttributedString(string: command, attributes: attributes))
		}

		if  second.length > 3 {
			if  type != .hDots {
				result.append(NSAttributedString(string: kTab))
			}

			result.append(NSAttributedString(string: second, attributes: attributes))
		}

		if  command.length + second.length < 11 && row != 1 && ![.hPlain].contains(type) {
			result.append(NSAttributedString(string: kTab)) 	// KLUDGE to fix bug in first column where underlined "KEY" doesn't have enough final tabs
		}

		result.append(NSAttributedString(string: kTab))

		return result
	}

	func url(for row: Int, column: Int) -> String? {
		let m = "https://medium.com/@sand_74696/"
		let (_, _, url) = strings(for: row, column: column)

		if  url.isHyphen || url.isEmpty {
			return nil
		}

		return m + url
	}

}
