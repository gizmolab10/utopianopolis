//
//  ZHelpDotsData.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

enum ZHelpDotType: String {
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
			r = r.insetEquallyBy(fraction: (1.0 - kSmallMapReduction) / 2.0)
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
		p.color       = gHelpHyperlinkColor
		p.fill        = isFilled ? p.color : gBackgroundColor
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
	override var tabOffsets        :  [Int]     { return [0, 20, 170] }
	override var columnWidth       :   Int      { return 580 }
	override var indexOfLastColumn :   Int      { return 1 }
	override var rowHeight         :   CGFloat  { return 22.0 }
	override var boldFont          :   ZFont    { return kLargeBoldFont }

	override func dotTypes(for row: Int, column: Int) -> (ZHelpDotType?, ZFillType?) {
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

	let dotsColumnOne: [String] = prefixArray + [
		"",						"",																				"",
		"!DRAG DOT",			"click to select, deselect or drag",											"",
		"",						"",																				"",
		"_drag dot",			"filled dots indicate idea is selected",										"",
		".b",					"editable",																		"",
		".b",					"not editable\t",																"",
		".b",					"only ideas in its list and sublists are editable",								"",
		"",						"",																				"",
		"_appears only in the favorite and recent lists",													"",	"",
		".b",					"target of this bookmark is the current focus",									""
	]

	let dotsColumnTwo: [String] = prefixArray + [
		"",						"",																				"",
		"!REVEAL DOT",			"click to conceal, reveal or activate",											"",
		"",						"",																				"",
		"_no dot indicates no list and nothing to activate",												"", "",
		"",						"",																				"",
		"_when list is visible","click to hide it",																"",
		".e",					"points to the left",															"",
		"",						"",																				"",
		"_when list is hidden",	"tiny dots indicate its size    click to reveal it",							"",
		".f",					"single idea      \t1 = small dot on right",									"",
		".f",					"3 ideas          \t3 = small dots all around",									"",
		".f",					"10 ideas         \t10 = medium dot on right",									"",
		".f",					"12 ideas         \t10 = medium dot on left, 2 = small dots on right",			"",
		".f",					"120 ideas        \t100 = large hollow dot on left, 20 = medium dots on right",	"",
		"",						"",																				"",
		"_decorated dot",		"to activate: ⌘-click or select and tap the = key",								"",
		".f",					"bookmark         \tfocus on the bookmark's target",							"",
		".b",					"email            \tcompose and send",											"",
		".b",					"hyperlink        \topen a browser",											"",
		".b",					"note or essay    \tview and edit",												""
	]

}
