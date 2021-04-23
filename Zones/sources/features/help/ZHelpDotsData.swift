//
//  ZHelpDotsData.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

let dotsPrefixArray = Array(repeating: "", count: 3 * 8)

class ZHelpDotsData: ZHelpData {

	override var noTabPrefix   :   String   { return "                    " }
	override var columnStrings : [[String]] { return [dotsColumnOne, dotsColumnTwo] }
	override var tabOffsets    :   [Int]    { return [0, 20, 150] }
	override var boldFont      :   ZFont    { return kLargeBoldFont }
	override var rowHeight     :  CGFloat   { return 22.0 }

	let dotsColumnOne: [String] = dotsPrefixArray + [
		"",						"",																				"",
		"!DRAG DOT",			"click to select, deselect or drag",											"",
		"",						"",																				"",
		"_drag dot",			"filled dot indicates idea is selected",										"",
		".b",					"editable",																		"",
		".b",					"not editable",																	"",
		".b",					"only the ideas in all its sublists are editable",								"",
		".b",					"member of a favorites group",													"",
		".b",					"owner of group",																"",
		"",						"",																				"",
		"_appears only in the favorite and recent lists",													"",	"",
		".b",					"this bookmark's target is current focus",										""
	]

	let dotsColumnTwo: [String] = dotsPrefixArray + [
		"",						"",																				"",
		"!REVEAL DOT",			"click to conceal, reveal or activate",											"",
		"",						"",																				"",
		"_no dot indicates nothing to reveal (no list, note, email or hyperlink)",							"", "",
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
		"_decorated dots",		"click to edit or select drag dot and tap the = key to ...",					"",
		".f",					"bookmark           focus on bookmark's target",								"",
		".f",					"target has note  ⌘-click to view note",										"",
		".b",					"email                   compose and send",										"",
		".b",					"hyperlink            open in a browser",										"",
		".b",					"note or essay     edit",												"",
		".b",					"video                   open in Quicktime",									""
	]

}
