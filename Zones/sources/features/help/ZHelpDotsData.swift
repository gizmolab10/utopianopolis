//
//  ZHelpDotsData.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZHelpDotsData: ZHelpData {

	override var noTabPrefix       :   String   { return "                    " }
	override var columnStrings     : [[String]] { return [dotsColumnOne, dotsColumnTwo] }
	override var tabOffsets        :  [Int]     { return [0, 20, 150] }
	override var columnWidth       :   Int      { return 580 }
	override var indexOfLastColumn :   Int      { return 1 }
	override var rowHeight         :   CGFloat  { return 22.0 }
	override var boldFont          :   ZFont    { return kLargeBoldFont }

	let dotsColumnOne: [String] = prefixArray + [
		"",						"",																				"",
		"!DRAG DOT",			"click to select, deselect or drag",											"",
		"",						"",																				"",
		"_drag dot",			"filled dots indicate idea is selected",										"",
		".b",					"editable",																		"",
		".b",					"not editable",																	"",
		".b",					"only ideas in its list and sublists are editable",								"",
		"",						"",																				"",
		"_appears only in the favorite and recent lists",													"",	"",
		".b",					"this bookmark's target is current focus",										""
	]

	let dotsColumnTwo: [String] = prefixArray + [
		"",						"",																				"",
		"!REVEAL DOT",			"click to conceal, reveal or activate",											"",
		"",						"",																				"",
		"_no dot indicates no list and nothing to activate",												"", "",
		"",						"",																				"",
		"_when list is visible","click to hide list",															"",
		".e",					"points to the left",															"",
		"",						"",																				"",
		"_when list is hidden",	"click to reveal list, surrounding dots indicate count, as in:",				"",
		".f",					"single idea          small dot right",											"",
		".f",					"3 ideas                3 small dots all around",								"",
		".f",					"10 ideas              medium dot right",										"",
		".f",					"12 ideas              medium dot left, 2 small dots right",					"",
		".f",					"120 ideas            large hollow left, 2 medium right",						"",
		".f",					"1200 ideas          large hollow left, 2 medium hollow right",					"",
		"",						"",																				"",
		"_decorated dots",		"click or select drag dot and tap the = key",									"",
		".f",					"bookmark           focus on bookmark's target",								"",
		".f",					"target has note  ⌘-click to view bookmark's target's note",					"",
		".b",					"email                   compose and send",										"",
		".b",					"hyperlink            open a browser",											"",
		".b",					"note or essay     view and edit",												""
	]

}
