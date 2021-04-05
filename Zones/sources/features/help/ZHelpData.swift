//
//  ZHelpData.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/9/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

enum ZHelpDotType: String {
	case one        = "single"
	case ten        = "10"
	case has        = "has"
	case note       = "note"
	case drag       = "editable"
	case three      = "3"
	case click      = "points"
	case email      = "email"
	case essay      = "click"
	case twelve     = "12"
	case relator    = "cycle"
	case progeny    = "only"
	case favorite   = "this"
	case bookmark   = "bookmark"
	case notemark   = "target"
	case oneTwenty  = "120"
	case hyperlink  = "hyperlink"
	case twelveHund = "1200"
	case unwritable = "not"

	var isReveal    : Bool            { return ![.drag, .essay, .relator, .favorite].contains(self) && !showAccess }
	var showAccess  : Bool            { return  [.progeny,              .unwritable].contains(self) }
	var pointLeft   : Bool            { return self == .click }
	var accessType  : ZDecorationType { return self == .progeny ? .sideDot : .vertical }

	var size: CGSize {
		let w = isReveal ? gDotHeight : gDotWidth

		return CGSize(width: w, height: gDotHeight)
	}

	func rect(_ origin: CGPoint) -> CGRect {
		var r = CGRect(origin: origin, size: size)

		if  self == .favorite {
			r = r.insetEquallyBy(fraction: (1.0 - kSmallMapReduction) / 2.0)
		}

		return r
	}

	var traitType: String {
		switch self {
			case .note,
				 .essay:     return ZTraitType.tNote     .rawValue
			case .email:     return ZTraitType.tEmail    .rawValue
			case .hyperlink: return ZTraitType.tHyperlink.rawValue
			default:         return ""
		}
	}

	var count: Int {
		switch self {
			case .twelveHund: return 1200
			case .oneTwenty:  return  120
			case .twelve:     return   12
			case .ten:        return   10
			case .three:      return    3
			case .one:        return    1
			default:          return    0
		}
	}

	func dotParameters(isFilled: Bool = false) -> ZDotParameters {
		var p         = ZDotParameters()
		p.color       = gHelpHyperlinkColor
		p.fill        = isFilled ? p.color : gBackgroundColor
		p.filled      = isFilled
		p.isReveal    = isReveal
		p.traitType   = traitType
		p.showAccess  = showAccess
		p.accessType  = accessType
		p.showList    = pointLeft || !isFilled
		p.isRelated   = self == .relator
		p.isNotemark  = self == .notemark || self == .has
		p.isBookmark  = self == .bookmark
		p.showSideDot = self == .favorite
		p.childCount  = count

		return p
	}

}

enum ZFillType: String {
	case filled = "f"
	case empty  = "e"
	case both   = "b"
}

class ZHelpData: NSObject {

	var helpMode          = ZHelpMode.noMode
	var tabStops          = [NSTextTab]()
	var rowHeight         :   CGFloat  { return 15.7 }
	var noTabPrefix       :   String   { return "   " }
	var columnStrings     : [[String]] { return [[]] }
	var tabOffsets        :   [Int]    { return [0, 20, 85] } // default for graph shortcuts
	var columnWidth       :    Int     { return 580 }         // "
	var indexOfLastColumn :    Int     { return 1 }           // "
	var stringsPerRow     :    Int     { return 3 }
	var isPro             :    Bool    { return gCurrentHelpMode == .proMode }
	var isDots            :    Bool    { return gCurrentHelpMode == .dotMode }
	var isBasic           :    Bool    { return gCurrentHelpMode == .basicMode }
	var isEssay           :    Bool    { return gCurrentHelpMode == .essayMode }
	var isIntermediate    :    Bool    { return gCurrentHelpMode == .middleMode }
	var boldFont          :    ZFont   { return kBoldFont }

	func dotTypes(for row: Int, column: Int) -> (ZHelpDotType?, ZFillType?) {
		let (first, second, _) = strings(for: row, column: column)
		let     shortcutLower  = first.substring(with: NSMakeRange(0, 1)).lowercased()
		let       filledLower  = first.substring(with: NSMakeRange(1, 2)).lowercased()
		let            filled  = ZFillType(rawValue: filledLower)
		var           dotType  : ZHelpDotType?
		if  let      helpType  = ZHelpType(rawValue: shortcutLower),
			helpType == .hDots {
			let         value  = second.components(separatedBy: " ")[0]
			dotType            = ZHelpDotType(rawValue: value)
		}

		return (dotType, filled)
	}

	var countOfRows : Int {
		var result = 0

		for array in columnStrings {
			result = max(result, array.count)
		}

		return result / stringsPerRow
	}

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
		let   final = index + 2

		return final >= strings.count ? ("", "", "") : (strings[index], strings[index + 1], strings[final])
	}

	func matches(_ types: [ZHelpType]) -> Bool {
		return  types.contains(.hBasic)
			|| (types.contains(.hPro) && isPro)
			|| (types.contains(.hIntermed) && (isIntermediate || isPro))
	}

	func strippedStrings(for column: Int) -> [String] {
		var             result = [String]()
		if              column > -1 {
			let     rawStrings = columnStrings[column]
			let          limit = rawStrings.count / stringsPerRow
			var            row = 0
			while          row < limit {
				let     offset = row * stringsPerRow
				let      first = rawStrings[offset]
				let     second = rawStrings[offset + 1]
				let      third = rawStrings[offset + 2]
				let (_, types) = extractTypes(from: first)
				let    isMatch = matches(types)
				row           += 1

				if     !types.contains(.hPro) || isPro {
					if  types.contains(.hExtra) {
						while result.count < 32 * 3 {
							result.append("")
						}
					} else if isPro || isDots || isEssay
								||  types.intersects([.hBold, .hBasic, .hEmpty])
								||  types.contains(.hUnderline) && isMatch
								|| (types.contains(.hIntermed)  && isIntermediate) {
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

		func extract(at location: Int) {
			let character = string.substring(with: NSMakeRange(location, 1))
			if  let  type = ZHelpType(rawValue: character.lowercased()) {
				types.append(type)
			}
		}

		extract(at: 0)
		extract(at: 1)

		if  types.count == 0 {
			types = [.hEmpty]
		}

		return (types.count, types)
	}

	func attributedString(for row: Int, column: Int) -> NSMutableAttributedString {
		var (first, second, url) = strings(for: row, column: column)
		let      (offset, types) = extractTypes(from: first)
		first                    = first.substring(fromInclusive: offset)    // grab remaining characters
		var           attributes = ZAttributesDictionary ()
		attributes[.font]        = isDots ? kLargeHelpFont : nil
		let               hasURL = !url.isEmpty
		var               prefix = ""

		if !isPro && !isDots && !isEssay && (types.contains(.hPro) || (!isIntermediate && types.contains(.hIntermed))) {
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
				case .hBasic, .hIntermed, .hPro:
					if  hasURL {
						attributes[.foregroundColor] = gHelpHyperlinkColor
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
		func appendText()   { result.append(NSAttributedString(string: first,  attributes: attributes)) }
		func appendSecond() { result.append(NSAttributedString(string: second, attributes: attributes)) }

		for (index, type) in types.enumerated() {
			let isFirst = index == 0

			switch type {
				case .hDots:
					break
				case .hBasic:
					appendText()
				case .hIntermed:
					if  isIntermediate || isPro {
						appendText()
					}
				default:
					if  isFirst {
						appendText()
					}
			}
		}

		if  second.length > 3 {
			appendTab()

			if  isDots || isEssay {
				appendSecond()
			} else {
				for type in types {
					switch type {
						case .hBasic:
							appendSecond()
						case .hIntermed:
							if  isIntermediate || isPro {
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

		appendTab()

		let    length = (first.length + second.length)
		let   isShort = (first == "SHIFT + KEY")  // length is 10, but still too short
		let threshold = (helpMode == .essayMode) || isShort ? 12 : 10

		if  length < threshold {                  // short string: needs an extra tab
			appendTab()
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
