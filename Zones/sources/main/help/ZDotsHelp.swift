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
	case drag       = "plain"
	case click      = "click"
	case email      = "email"
	case focus      = "current"
	case fifteen    = "fifteen"
	case progeny    = "progeny"
	case bookmark   = "bookmark"
	case hyperlink  = "hyperlink"
	case unwritable = "editing"

	var traitType: String {
		switch self {
			case .note:      return ZTraitType.tNote     .rawValue
			case .email:     return ZTraitType.tEmail    .rawValue
			case .hyperlink: return ZTraitType.tHyperlink.rawValue
			default:         return ""
		}
	}

	var pointRight: Bool {
		switch self {
			case .click: return true
			default:     return false
		}
	}

	var isReveal: Bool {
		switch self {
			case .unwritable,
				 .progeny,
				 .focus,
				 .drag: return false
			default:    return true
		}
	}

	var count: Int {
		switch self {
			case .one:     return  1
			case .five:    return  5
			case .ten:     return 10
			case .fifteen: return 15
			default:       return  0
		}
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
		"",						"",												"",
		"bLEFT SIDE DOTS",		"click to select, deselect or drag",			"",
		"",						"",												"",
		"db",					"plain",										"",
		"db",					"current focus (only in favorites or recents)",	"",
		"db",					"editing not permitted",						"",
		"db",					"progeny are writable",							""
	]

	let dotsColumnTwo: [String] = [
		"",		"",																"",
		"bRIGHT SIDE DOTS",		"click to conceal, reveal or activate",			"",
		"",						"",												"",
		"ulist is visible",		"",												"",
		"",						"",												"",
		"de",					"click to hide ideas",							"",
		"",						"",												"",
		"ulist is hidden (dots indicate count)",	"",							"",
		"",						"",												"",
		"df",					"one idea",										"",
		"df",					"five ideas",									"",
		"df",					"ten ideas",									"",
		"df",					"fifteen ideas",								"",
		"",						"",												"",
		"udecorated",			"",												"",
		"",						"",												"",
		"df",					"bookmark",										"",
		"db",					"email",										"",
		"db",					"hyperlink",									"",
		"db",					"note or essay",								""
	]

}
