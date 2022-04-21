//
//  ZHelpData.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/9/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

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
	case owner      = "owner"
	case member     = "member"
	case twelve     = "12"
	case progeny    = "only"
	case favorite   = "this"
	case bookmark   = "bookmark"
	case notemark   = "target"
	case oneTwenty  = "120"
	case hyperlink  = "hyperlink"
	case twelveHund = "1200"
	case unwritable = "not"

	var isReveal    : Bool            { return ![.drag, .essay, .member, .owner, .favorite].contains(self) && !showAccess }
	var showAccess  : Bool            { return  [.progeny,                     .unwritable].contains(self) }
	var pointLeft   : Bool            { return self == .click }
	var accessType  : ZDecorationType { return self == .progeny ? .sideDot : .vertical }

	var size: CGSize {
		return gDotSize(forReveal: isReveal)
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
			default:         return kEmpty
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

	func helpDotParameters(isFilled: Bool = false) -> ZDotParameters {
		var p           = ZDotParameters()
		p.color         = gHelpHyperlinkColor
		p.fill          = isFilled ? p.color : gBackgroundColor
		p.filled        = isFilled
		p.isReveal      = isReveal
		p.typeOfTrait   = traitType
		p.showAccess    = showAccess
		p.accessType    = accessType
		p.showList      = pointLeft || !isFilled
		p.isGroupOwner  = self == .owner
		p.isGrouped     = self == .owner    || self == .member
		p.hasTargetNote = self == .notemark || self == .has
		p.hasTarget     = self == .bookmark
		p.showSideDot   = self == .favorite
		p.childCount    = count

		return p
	}

}

enum ZHelpType: String {
	case hPro       = "2"
	case hBold      = "!"
	case hDots      = "."
	case hSkip      = "="
	case hExtra     = "+"
	case hEmpty     = "-"
	case hBasic     = "0"
	case hIntermed  = "1"
	case hUnderline = "_"

	var isVisibleForCurrentMode: Bool {
		switch gCurrentHelpMode {
			case .basicMode:  return self == .hBasic
			case .middleMode: return self == .hBasic || self == .hIntermed
			case .proMode:    return self == .hBasic || self == .hIntermed || self == .hPro
			default:          return false
		}
	}
}

enum ZFillType: String {
	case filled = "f"
	case empty  = "e"
	case both   = "b"
}

class ZHelpData: NSObject {

	let rowsBeforeSearch  = 31
	var helpMode          = ZHelpMode.noMode
	var tabStops          = [NSTextTab]()
	var strippedStrings   = [StringsArray]()
	var columnStrings     : [StringsArray] { return [[]] }
	var rowHeight         :  CGFloat       { return 17.0 }
	var noTabPrefix       :  String        { return "   " }
	var tabOffsets        : [Int]          { return [0, 20, 85] } // default for graph shortcuts
	var columnWidth       :  Int           { return 580 }         // "
	var indexOfLastColumn :  Int           { return 1 }           // "
	var stringsPerColumn  :  Int           { return 3 }
	var isPro             :  Bool          { return gCurrentHelpMode == .proMode }
	var isDots            :  Bool          { return gCurrentHelpMode == .dotMode }
	var isBasic           :  Bool          { return gCurrentHelpMode == .basicMode }
	var isEssay           :  Bool          { return gCurrentHelpMode == .essayMode }
	var isIntermediate    :  Bool          { return gCurrentHelpMode == .middleMode }
	var boldFont          :  ZFont         { return kBoldFont }

	func dotTypes(for row: Int, column: Int) -> (ZHelpDotType?, ZFillType?) {
		let (first, second, _) = strings(for: row, column: column)
		let     shortcutLower  = first.substring(with: NSMakeRange(0, 1)).lowercased()
		let       filledLower  = first.substring(with: NSMakeRange(1, 2)).lowercased()
		let            filled  = ZFillType(rawValue: filledLower)
		var           dotType  : ZHelpDotType?
		if  let      helpType  = ZHelpType(rawValue: shortcutLower),
			helpType == .hDots {
			let         value  = second.components(separatedBy: kSpace)[0]
			dotType            = ZHelpDotType(rawValue: value)
		}

		return (dotType, filled)
	}

	var countOfRows : Int {
		var count = 0

		for column in 0...indexOfLastColumn {
			let a = strippedStrings[column]
			let c = a.count / stringsPerColumn
			count = max(count, c)
		}

		return count
	}

	func setupForMode(_ iMode: ZHelpMode) {
		helpMode   = iMode
		var offset = 0
		var values : [Int] = []

		for _ in 0...indexOfLastColumn {
			for index in 0..<stringsPerColumn {
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
		let    objectValue = NSMutableAttributedString()
		let      paragraph = NSMutableParagraphStyle()
		paragraph.tabStops = tabStops

		for column in 0...indexOfLastColumn {
			let a = attributedString(for: row, column: column)

			objectValue.append(a)
		}

		objectValue.addAttribute(.paragraphStyle, value: paragraph as Any, range: NSMakeRange(0, objectValue.length))

		return objectValue
	}

	func strings(for row: Int, column: Int) -> (String, String, String) {
		let strings = strippedStrings[column]
		let index   = row * stringsPerColumn
		if  index   > (strings.count - 2) {
			return (kEmpty, kEmpty, kEmpty)
		}

		if  strings[index] == "0!legend" {
			noop()
		}

		return (strings[index], strings[index + 1], strings[index + 2])
	}

	func matches(_ types: [ZHelpType]) -> Bool {
		return  types.contains(.hBasic)
			|| (types.contains(.hPro) && isPro)
			|| (types.contains(.hIntermed) && (isIntermediate || isPro))
	}

	func prepareStrings() {
		for column in 0...indexOfLastColumn {
			var       prepared = StringsArray()
			let     rawStrings = columnStrings[column]
			let          limit = rawStrings.count / stringsPerColumn
			var            row = 0
			while          row < limit {
				let      index = row * stringsPerColumn
				let      first = rawStrings[index]
				let     second = rawStrings[index + 1]
				let      third = rawStrings[index + 2]
				let (_, types) = extractTypes(from: first)
				let    isMatch = matches(types)
				row           += 1

				if     !types.contains(.hPro) || isPro {
					if  types.contains(.hExtra) {
						while prepared.count < rowsBeforeSearch * 3 {
							prepared.append(kEmpty)
						}
					} else if isPro || isDots || isEssay
								||  types.intersects([.hBold, .hBasic, .hEmpty])
								||  types.contains(.hUnderline) && isMatch
								|| (types.contains(.hIntermed)  && isIntermediate) {
						prepared.append(first)
						prepared.append(second)
						prepared.append(third)
					}
				}
			}

			strippedStrings.append(prepared)
		}
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
		var               prefix = kEmpty

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
					if  index == 0 {
						appendText()
					}
			}
		}

		if  second.length > 3 {
			appendTab()

			if  first.length == 0 {
				appendTab()
				if  column == 2, attributedString(for: row, column: 1).string.containsNonTabs {
					appendTab()
				}
			}

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
		let threshold = (helpMode == .essayMode) || isShort ? 12 : 6

		if  length < threshold {                  // short string: needs an extra tab
			appendTab()
		}

		return result
	}

	func url(for row: Int, column: Int) -> String? {
		let m = "https://medium.com/@sand_74696/"
		let (first, _, url) = strings(for: row, column: column)
		let (_, types) = extractTypes(from: first)

		if  !url.isHyphen, !url.isEmpty {
			for type in types {
				if  type.isVisibleForCurrentMode {
					return m + url
				}
			}
		}

		return nil
	}

}
