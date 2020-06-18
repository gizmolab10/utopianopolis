//
//  ZHelpDotsData.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

enum ZDotConfigurationType: String {
	case one        = "single"
	case ten        = "10"
	case note       = "note"
	case drag       = "editable"
	case three      = "3"
	case click      = "points"
	case email      = "email"
	case twelve     = "12"
	case progeny    = "only"
	case favorite   = "target"
	case bookmark   = "bookmark"
	case oneTwenty  = "120"
	case hyperlink  = "hyperlink"
	case unwritable = "not"

	var isReveal    : Bool            { return ![.progeny, .unwritable, .drag, .favorite].contains(self) }
	var showAccess  : Bool            { return  [.progeny, .unwritable                  ].contains(self) }
	var pointLeft   : Bool            { return self == .click }
	var accessType  : ZDecorationType { return self == .progeny ? .sideDot : .vertical }

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
			case .one:       return   1
			case .three:     return   3
			case .ten:       return  10
			case .twelve:    return  12
			case .oneTwenty: return 120
			default:         return   0
		}
	}

	func dotParameters(isFilled: Bool = false) -> ZDotParameters {
		var p         = ZDotParameters()
		p.color       = gIsDark  ? kWhiteColor : kBlackColor
		p.fill        = isFilled ? p.color     : gBackgroundColor
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

let prefixArray : [String] = Array(repeating: "", count: 24)

class ZHelpDotsData: ZHelpData {

	override var noTabPrefix       :   String   { return "                    " }
	override var columnStrings     : [[String]] { return [dotsColumnOne, dotsColumnTwo] }
	override var tabOffsets        :  [Int]     { return [0, 20, 150] }
	override var columnWidth       :   Int      { return 580 }
	override var indexOfLastColumn :   Int      { return 1 }
	override var rowHeight         :   CGFloat  { return 22.0 }

	override func dotTypes(for row: Int, column: Int) -> (ZDotConfigurationType?, ZFillType?) {
		var           command  : ZDotConfigurationType?
		var            filled  : ZFillType?
		let (first, second, _) = strings(for: row, column: column)
		let     shortcutLower  = first.substring(with: NSMakeRange(0, 1)).lowercased()
		let       filledLower  = first.substring(with: NSMakeRange(1, 2)).lowercased()
		filled                 = ZFillType(rawValue: filledLower)
		if  let      helpType  = ZHelpType(rawValue: shortcutLower),
		             helpType == .hDots {
			let configuration  = second.components(separatedBy: " ")[0]
			command            = ZDotConfigurationType(rawValue: configuration)
		}

		return (command, filled)
	}

	let dotsColumnOne: [String] = prefixArray + [
		"",						"",																				"",
		"bDRAG DOT",			"click to select, deselect or drag",											"",
		"",						"",																				"",
		"udrag dot",			"filled dots indicate idea is selected",										"",
		"db",					"editable",																		"",
		"db",					"not editable\t",																"",
		"db",					"only ideas in its list and sublists are editable",								"",
		"",						"",																				"",
		"uappears only in the favorite and recent lists",													"",	"",
		"db",					"target of this bookmark is the current focus",									""
	]

	let dotsColumnTwo: [String] = prefixArray + [
		"",						"",																				"",
		"bREVEAL DOT",			"click to conceal, reveal or activate",											"",
		"",						"",																				"",
		"uno dot indicates no list and nothing to activate",												"", "",
		"",						"",																				"",
		"uwhen list is visible","click to hide it",																"",
		"de",					"points to the left",															"",
		"",						"",																				"",
		"uwhen list is hidden",	"tiny dots indicate its size    click to reveal it",							"",
		"df",					"single idea      \t1 = small dot on right",									"",
		"df",					"3 ideas          \t3 = small dots all around",									"",
		"df",					"10 ideas         \t10 = medium dot on right",									"",
		"df",					"12 ideas         \t10 = medium dot on left, 2 = small dots on right",			"",
		"df",					"120 ideas        \t100 = large hollow dot on left, 20 = medium dots on right",	"",
		"",						"",																				"",
		"udecorated dot",		"to activate: ⌘-click or select and tap the = key",								"",
		"df",					"bookmark         \tfocus on the bookmark's target",							"",
		"db",					"email            \tcompose and send",											"",
		"db",					"hyperlink        \topen a browser",											"",
		"db",					"note or essay    \tview and edit",												""
	]

}
