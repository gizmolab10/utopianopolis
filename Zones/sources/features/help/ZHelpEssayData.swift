//
//  ZHelpNotesData.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

let essayPrefixArray = Array(repeating: "", count: 3 * 12)

class ZHelpEssayData: ZHelpData {

	override var noTabPrefix   :   String   { return "                    " }
	override var columnStrings : [[String]] { return [essayColumnOne, essayColumnTwo] }
	override var tabOffsets    :   [Int]    { return [0, 20, 180] }

	let essayColumnOne: [String] = essayPrefixArray + [
		"",																								"",	"",
		"!GRAPHICS",																					"",	"",
		"",																								"",	"",
		"_drag dot",					"click to grab or ungrab the note",									"",
		".b",							"filled dot indicates note contains cursor or is grabbed",			"",
		"",																								"",	"",
		"_reveal dot",					"COMMAND-click it to edit the note or essay, when it ...",			"",
		".f",							"has two tiny dots inside",											"",
		"",																								"",	""
	]

	let essayColumnTwo: [String] = essayPrefixArray + [
		"",																								"",	"",
		"!KEYS, ALWAYS",							 													"", "",
		"",																								"",	"",
		"_KEY",			 																				"", "",
		"0ESCAPE", 						"discard unsaved changes and exit editor",				 			"",
		"",																								"",	"",
		"_COMMAND + KEY", 																				"", "",
		"0RETURN", 						"save changes and exit editor",										"",
		"0[ or ]",						"save changes and edit the prior or next essay (or note)",			"",
		"0S",							"save changes",														"",
		"",																								"",	"",
		"",																								"",	"",
		"!KEYS, WHEN NO NOTES ARE GRABBED",			 													"", "",
		"",																								"",	"",
		"_COMMAND + KEY", 																				"", "",
		"0N",							"save changes and swap between essay and note",						"",
		"",																								"",	"",
		"",																								"",	"",
		"!WHEN ONE OR MORE NOTES ARE GRABBED", 															"", "",
		"",																								"",	"",
		"_KEY",			 																				"", "",
		"0ARROWS (vertical)",			"grab a different note", 											"",
		"0ARROWS (vertical) + SHIFT",	"grab an additional note", 											"",
		"0ARROWS + OPTION",				"move them", 														"",
		"0DELETE", 						"destroy and remove them",											"",
		"0N",							"save changes and swap between essay and first grabbed note",		"",
		"",					 																			"",	""
	]

}
