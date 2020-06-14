//
//  ZDotsHelp.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

enum ZDotCommand: String {
	case ten        = "ten"
	case one        = "one"
	case five       = "five"
	case note       = "note"
	case drag       = "ordinary"
	case click      = "click"
	case email      = "email"
	case fifteen    = "fifteen"
	case hundred    = "hundred"
	case progeny    = "progeny"
	case favorite   = "target"
	case bookmark   = "bookmark"
	case hyperlink  = "hyperlink"
	case unwritable = "editing"

	var pointLeft:  Bool { return self == .click }
	var showAccess: Bool { return  [.progeny, .unwritable                  ].contains(self) }
	var isReveal:   Bool { return ![.progeny, .unwritable, .drag, .favorite].contains(self) }
	var accessType: ZoneDot.ZDecorationType { return self == .progeny ? .sideDot : .vertical }

	var size: CGSize {
		let w = isReveal ? gDotHeight : gDotWidth

		return CGSize(width: w, height: gDotHeight)
	}

	func rect(_ origin: CGPoint) -> CGRect {
		var r = CGRect(origin: origin, size: size)

		if  self == .favorite {
			r = r.insetEquallyBy(fraction: (1.0 - kFavoritesReduction) / 2.0)
		}

		return r
	}

	var traitType: String {
		switch self {
			case .note:      return ZTraitType.tNote     .rawValue
			case .email:     return ZTraitType.tEmail    .rawValue
			case .hyperlink: return ZTraitType.tHyperlink.rawValue
			default:         return ""
		}
	}

	var count: Int {
		switch self {
			case .one:     return   1
			case .five:    return   5
			case .ten:     return  10
			case .fifteen: return  15
			case .hundred: return 100
			default:       return   0
		}
	}

	func dotParameters(isFilled: Bool = false) -> ZoneDot.ZDotParameters {
		var p         = ZoneDot.ZDotParameters()
		p.fill        = isFilled ? p.color.lighter(by: 2.5) : gBackgroundColor
		p.filled      = isFilled
		p.isReveal    = isReveal
		p.traitType   = traitType
		p.showAccess  = showAccess
		p.accessType  = accessType
		p.showList    = pointLeft || !isFilled
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

class ZDotsHelp: ZHelp {

	override var noTabPrefix       :   String   { return "                   " }
	override var columnStrings     : [[String]] { return [dotsColumnOne, dotsColumnTwo] }
	override var tabOffsets        :  [Int]     { return [0, 20, 150] }
	override var columnWidth       :   Int      { return 580 }
	override var indexOfLastColumn :   Int      { return 1 }

	override func dotCommand(for row: Int, column: Int) -> (ZDotCommand?, ZFillType?) {
		var           command  : ZDotCommand?
		var            filled  : ZFillType?
		let (first, second, _) = strings(for: row, column: column)
		let     shortcutLower  = first.substring(with: NSMakeRange(0, 1)).lowercased()
		let       filledLower  = first.substring(with: NSMakeRange(1, 2)).lowercased()
		filled                 = ZFillType(rawValue: filledLower)
		if  let  shortcutType  = ZShortcutType(rawValue: shortcutLower),
		         shortcutType == .dots {
			let       dotType  = second.components(separatedBy: " ")[0]
			command            = ZDotCommand(rawValue: dotType)
		}

		return (command, filled)
	}

	let dotsColumnOne: [String] = [
		"",						"",													"",
		"bLEFT SIDE DOTS",		"click to select, deselect or drag",				"",
		"",						"",													"",
		"ushown on right, filled dots indicate idea is selected",				"", "",
		"",						"",													"",
		"db",					"ordinary drag dot",								"",
		"db",					"progeny are editable",								"",
		"db",					"editing not permitted",							"",
		"",						"",													"",
		"uonly in the favorite or recent lists",								"",	"",
		"",						"",													"",
		"db",					"target of this bookmark is the current focus",		""
	]

	let dotsColumnTwo: [String] = [
		"",		"",																	"",
		"bRIGHT SIDE DOTS",		"click to conceal, reveal or activate",				"",
		"",						"",													"",
		"ulist is visible",														"", "",
		"",						"",													"",
		"de",					"click to hide list",								"",
		"",						"",													"",
		"ulist is hidden (click to reveal. dots indicate count)",				"", "",
		"",						"",													"",
		"df",					"one idea",											"",
		"df",					"five ideas",										"",
		"df",					"ten ideas",										"",
		"df",					"fifteen ideas",									"",
		"df",					"hundred ideas",									"",
		"",						"",													"",
		"udecorated (⌘-click to activate)",										"", "",
		"",						"",													"",
		"df",					"bookmark",											"",
		"db",					"email",											"",
		"db",					"hyperlink",										"",
		"db",					"note or essay",									""
	]

}
