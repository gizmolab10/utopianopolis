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
	var isDots            :    Bool    { return gCurrentHelpMode == .dotMode }
	var isBasic           :    Bool    { return gCurrentHelpMode == .basicMode }
	var isMedium          :    Bool    { return gCurrentHelpMode == .mediumMode }
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
		var             result = [String]()
		if              column > -1 {
			let     rawStrings = columnStrings[column]
			let          count = rawStrings.count / stringsPerRow
			var            row = 0
			while          row < count {
				let     offset = row * stringsPerRow
				let      first = rawStrings[offset]
				let     second = rawStrings[offset + 1]
				let      third = rawStrings[offset + 2]
				let (_, types) = extractTypes(from: first)
				row           += 1

				if      isPro || !types.contains(.hPro) {
					if !isPro &&  types.contains(.hInsert) {
						while result.count < 90 {
							result.append("")
						}
					} else if isPro || isDots
								||  types.contains(.hBold)
								||  types.contains(.hEmpty)
								||  types.contains(.hPlain)
								||  types.contains(.hUnderline)
								|| (types.contains(.hMedium) && isMedium) {
						result.append(first)
						result.append(second)
						result.append(third)
					}
				}
			}
		}

		return result
	}

	func extractTypes(from string: String) -> (Int, [ZHelpType]) {
		var types = [ZHelpType]()

		func extract(at index: Int) {
			let character = string.substring(with: NSMakeRange(index, 1))
			if  let  type = ZHelpType(rawValue: character.lowercased()) {
				types.append(type)
			}
		}

		extract(at: 0)
		extract(at: 1)

		if  types.count == 0 {
			types.append(.hEmpty)
		}

		return (types.count, types)
	}

	func attributedString(for row: Int, column: Int) -> NSMutableAttributedString {
		var (first, second, url) = strings(for: row, column: column)
		let      (offset, types) = extractTypes(from: first)
		let                 text = first.substring(fromInclusive: offset)    // grab remaining characters
		var           attributes = ZAttributesDictionary ()
		let               hasURL = !url.isEmpty
		var               prefix = ""

		switch gCurrentHelpMode {
			case .dotMode: attributes[.font] = kLargeHelpFont
			default:       attributes[.font] = nil
		}

		if !isPro && !isDots && (types.contains(.hPro) || (!isMedium && types.contains(.hMedium))) {
			return NSMutableAttributedString(string: kTab + kTab + kTab)
		}

		for type in types {
			switch type {
				case .hDots:
					prefix = noTabPrefix
				case .hBold:
					attributes[.font] = boldFont
				case .hUnderline:
					attributes[.underlineStyle] = 1
				case .hPlain, .hMedium, .hPro:
					if  hasURL {
						attributes[.foregroundColor] = gHelpHyperlinkColor

						if !url.isHyphen {
							second.append(kSpace + kEllipsis)
						}
					}

					fallthrough

				default:
					if  offset == 1 {       // only if single type specified
						prefix = kTab		// for empty lines, including after last row
					}
			}
		}

		let result = NSMutableAttributedString(string: prefix)

		func appendTab()    { result.append(NSAttributedString(string: kTab)) }
		func appendText()   { result.append(NSAttributedString(string: text,   attributes: attributes)) }
		func appendSecond() { result.append(NSAttributedString(string: second, attributes: attributes)) }

		for (index, type) in types.enumerated() {
			let isFirst = index == 0

			switch type {
				case .hDots:
					break
				case .hPlain:
					appendText()
				case .hMedium:
					if  isMedium || isPro {
						appendText()
					}
				default:
					if  isFirst {
						appendText()
					}
			}
		}

		if  second.length > 3 {
			if  types.contains(.hDots) {
				appendSecond()
			} else{
				appendTab()

				for type in types {
					switch type {
						case .hPlain:
							appendSecond()
						case .hMedium:
							if  isMedium || isPro {
								appendSecond()
							}
						case .hPro:
							if  isPro {
								appendSecond()
							} else {
								appendTab()
							}
						default:
							break
					}
				}
			}
		}

		if  text.length + second.length < 10 && row != 1 && !types.contains(.hPlain) {
			appendTab() 	// KLUDGE to fix bug in first column where underlined "KEY" doesn't have enough final tabs
		}

		appendTab()

		if  result == NSAttributedString(string: kTab + kTab + kTab + kTab), column < 3 {
			print("row: \(row), column: \(column)")
		}

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
