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

class ZHelpData: NSObject {

	let rowsBeforeSearch  = 33
	var helpMode          = ZHelpMode.noMode
	var tabStops          = [NSTextTab]()
	var strippedStrings   = [StringsArray]()
	var columnStrings     : [StringsArray] { return [[]] }
	var rowHeight         :  CGFloat       { return 16.0 }
	var dotOffset         :  CGFloat       { return  2.1 }
	var noTabPrefix       :  String        { return "   " }
	var tabOffsets        : [Int]          { return [0, 20, 85] }
	var columnWidth       :  Int           { return 580 }
	var indexOfLastColumn :  Int           { return 1 }
	var stringsPerColumn  :  Int           { return 3 }
	var isPro             :  Bool          { return gCurrentHelpMode == .proMode }
	var isDots            :  Bool          { return gCurrentHelpMode == .dotMode }
	var isBasic           :  Bool          { return gCurrentHelpMode == .basicMode }
	var isEssay           :  Bool          { return gCurrentHelpMode == .essayMode }
	var isIntermediate    :  Bool          { return gCurrentHelpMode == .intermedMode }
	var italicsFont       :  ZFont         { return kItalicsFont }
	var boldFont          :  ZFont         { return kBoldFont }

	func dotTypes(for row: Int, column: Int) -> (ZHelpDotType?, ZFillType?) {
		let (first, second, _) = strings(for: row, column: column)
		let       helpTypeRaw  = first.substring(with: NSMakeRange(0, 1)).lowercased()
		let         filledRaw  = first.substring(with: NSMakeRange(1, 2)).lowercased()
		let          fillType  = ZFillType(rawValue: filledRaw)
		var           dotType  : ZHelpDotType?
		if  let      helpType  = ZHelpType(rawValue: helpTypeRaw),
			helpType == .hDots {
			let    dotTypeRaw  = second.componentsSeparatedBySpace[0]
			dotType            = ZHelpDotType(rawValue: dotTypeRaw)
		}

		return (dotType, fillType)
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
				tabStops.append(NSTextTab(textAlignment: .left, location: value.float, options: [:]))
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

		return (strings[index], strings[index + 1], strings[index + 2])
	}

	func matches(_ types: [ZHelpType]) -> Bool {
		return  types.contains(.hBasic)
			|| (types.contains(.hPro) && isPro)
			|| (types.contains(.hIntermed) && (isIntermediate || isPro))
	}

	func prepareStrings() {
		strippedStrings.removeAll()

		for column in 0...indexOfLastColumn {
			let        strings = columnStrings
			var       prepared = StringsArray()
			let     rawStrings = strings.count <= column ? [kEmpty] : strings[column]
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
					prefix                           = noTabPrefix
				case .hBold:               
					attributes[.font]                = boldFont
					attributes[.foregroundColor]     = gHelpTitleColor
				case .hItalics:               
					attributes[.font]                = italicsFont
				case .hUnderline:     
					attributes[.underlineStyle]      = 1
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
				if  column == 2, attributedString(for: row, column: 1).string.containsNoTabs {
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
		let   isShort = (first == "ARROW KEY")  // length is 8, but still too short
		let threshold = (helpMode == .essayMode) || isShort ? 12 : 6

		if  length < threshold {                  // short string: needs an extra tab
			appendTab()
		}

		return result
	}

	func url(for row: Int, column: Int) -> String? {
		let (first, _, name) = strings(for: row, column: column)

		if  !name.isHyphen, !name.isEmpty {
			let (_, types) = extractTypes(from: first)
			for type in types {
				if  type.isVisibleForCurrentMode {
					return name.asHelpURL
				}
			}
		}

		return nil
	}

}

extension String {

	var asHelpURL: String? {
		let   parts = components(separatedBy: "+")
		let   count = parts.count
		guard count > 0 else { return nil }
		let   proto = "https://"
		let  medium = "medium.com/@sand_74696/"
		let    wiki = "seriouslythink.com/"
		let    base = count == 1 ? medium : wiki + (ZHelpSectionID(rawValue: parts[1])?.description ?? kEmpty)

		return proto + base + parts[0]
	}

}

enum ZHelpDotType: String {
	case one        = "single"
	case ten        = "10"
	case has        = "in"
	case both       = "both"
	case note       = "note"
	case drag       = "editable"
	case five       = "5"
	case click      = "points"
	case email      = "email"
	case essay      = "click"
	case owner      = "owner"
	case member     = "member"
	case eleven     = "11"
	case progeny    = "ideas"
	case favorite   = "this"
	case notemark   = "target"
	case bookmark   = "bookmark"
	case multiple   = "multiple"
	case hyperlink  = "hyperlink"
	case oneEleven  = "111"
	case unwritable = "not"

	var accessType    :    ZDecorationType { return self == .progeny ? .sideDot : .vertical }
	var pointLeft     :               Bool { return self == .click }
	var showAccess    :               Bool { return  [.both, .unwritable,              .progeny].contains(self) }
	var isReveal      :               Bool { return ![.drag, .essay, .member, .owner, .favorite].contains(self) && !showAccess }
	var size          :             CGSize { return gHelpController?.dotSize(forReveal: isReveal) ?? .zero }
	func rect(_ origin: CGPoint) -> CGRect { return CGRect(origin: origin, size: size) }

	var traitTypes: StringsArray {
		switch self {
			case .note, .essay: return [ZTraitType.tNote     .rawValue]
			case .email:        return [ZTraitType.tEmail    .rawValue]
			case .hyperlink:    return [ZTraitType.tHyperlink.rawValue]
			case .multiple:     return  ZTraitType.activeTypes.map { $0.rawValue }
			default:            return []
		}
	}

	var childCount: Int {
		switch self {
			case .oneEleven: return 111
			case .eleven:    return  11
			case .ten:       return  10
			case .five:      return   5
			case .one:       return   1
			default:         return   0
		}
	}

	func helpDotParameters(isFilled: Bool = false, showAsACircle: Bool = false) -> ZDotParameters {
		var p           = ZDotParameters()
		p.color         = gHelpHyperlinkColor
		p.fill          = isFilled ? p.color : gBackgroundColor
		p.isFilled      = isFilled
		p.isReveal      = isReveal
		p.typesOfTrait  = traitTypes
		p.showAccess    = showAccess
		p.accessType    = accessType
		p.showList      = pointLeft || !isFilled
		p.isGroupOwner  = self == .owner
		p.isGrouped     = self == .owner    || self == .both || self == .member
		p.hasTargetNote = self == .notemark || self == .has
		p.hasTarget     = self == .bookmark
		p.showSideDot   = self == .favorite
		p.childCount    = showAsACircle ? 0 : childCount
		p.isCircle      = showAsACircle || p.hasTarget || p.hasTargetNote

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
	case hPlain     = " "
	case hItalics   = "i"
	case hIntermed  = "1"
	case hUnderline = "_"

	var isVisibleForCurrentMode: Bool {
		switch gCurrentHelpMode {
			case .basicMode:    return self == .hBasic
			case .intermedMode: return self == .hBasic || self == .hIntermed
			case .proMode:      return self == .hBasic || self == .hIntermed || self == .hPro
			default:            return false
		}
	}
}

enum ZFillType: String {
	case fFilled = "f"
	case fEmpty  = "e"
	case fBoth   = "b"
	case fThree  = "3"
}

enum ZHelpSectionID: String {
	case sBasic        = "b"
	case sIntermediate = "i"
	case sAdvanced     = "a"

	var description : String {
		switch self {
			case .sBasic:        return "basic/"
			case .sIntermediate: return "intermediate/"
			case .sAdvanced:     return "advanced/"
		}
	}
}
