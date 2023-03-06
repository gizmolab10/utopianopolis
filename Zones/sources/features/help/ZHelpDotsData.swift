//
//  ZHelpDotsData.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

let emptyTopRowsCount = 9
let dotsPrefixArray = Array(repeating: kEmpty, count: 3 * emptyTopRowsCount)

class ZHelpDotsData: ZHelpData {

	override var noTabPrefix   :  String        { return "                    " }
	override var columnStrings : [StringsArray] { return [dotsColumnOne, dotsColumnTwo] }
	override var tabOffsets    : [Int]          { return [0, 20, 165] }
	override var italicsFont   :  ZFont         { return kLargeItalicsFont }
	override var boldFont      :  ZFont         { return kLargeBoldFont }
	override var rowHeight     :  CGFloat       { return 21.0 }

	let dotsColumnOne: StringsArray = dotsPrefixArray + [
		"",							"",																				"",
		"!DRAG DOT",				"click to select, deselect or drag",											"",
		"",							"",																				"",
		"!filled drag dot",			"indicates idea is selected, or cursor is hovering over",						"",
		".b",						"editable",																		"",
		".b",						"not editable",																	"",
		".b",						"only the ideas in all its sublists are editable",								"",
		".b",						"owner of a favorites group",													"",
		".b",						"member of a favorites group",													"",
		"",							"",																				"",
		"!appears only in favorites",																			"",	"",
		".b",						"this bookmark's target is the current focus",									""
	]

	let dotsColumnTwo: StringsArray = dotsPrefixArray + [
		"",							"",																				"",
		"!REVEAL DOT",				"click to conceal, reveal or activate",											"",
		"",							"",																				"",
		"!no reveal dot",			"indicates nothing to reveal (no list or traits)",								"",
		"",							"",																				"",
		"!when list is visible",	"click to hide list",															"",
		".e",						"points to the left",															"",
		"",							"",																				"",
		"!when list is hidden",		"click to reveal list, surrounding dots indicate count:",						"",
		".f",						"single idea             one small dot",										"",
		".f",						"5 ideas                   five small dots all around",							"",
		".f",						"10 ideas                 medium dot right",									"",
		".f",						"11 ideas                  medium dot left, small dot right",					"",
		".f",						"111 ideas                large hollow dot left, medium dot right",				"",
		"",							"                               (shows as 110, close enough, right?)",			"",
		"",							"",																				"",
		"!bookmark decorations",	"(always a filled circle) click to change focus", 								"",
		".f",						"bookmark              focus on bookmark's target",								"",
		".f",						"target has a note  same, and also ⌘-click to edit note",						"",
		"",							"",					 															"",
		"!trait decorations",		"tap \"h\" to edit:    tap \"=\" to:",											"",
		"i but, if it's a circle (third column of dots)",		"       click to:",									"",
		".3",						"email                      compose & send",									"",
		".3",						"hyperlink               open in a browser",									"",
		".3",						"note                       edit",												""
	]

}
