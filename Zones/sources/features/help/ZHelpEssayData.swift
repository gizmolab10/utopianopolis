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
	override var tabOffsets    :   [Int]    { return [0, 20, 170] }

	let essayColumnOne: [String] = essayPrefixArray + [
		"",																				"",	"",
		"!GRAPHICS",																	"",	"",
		"",																				"",	"",
		"_drag dot",			"click to grab the note",									"",
		".b",					"filled dot indicates note contains cursor or is grabbed",	"",
		"",																				"",	""
	]

	let essayColumnTwo: [String] = essayPrefixArray + [
		"",																				"",	"",
		"!KEYS, ALWAYS",					 											"", "",
		"",																				"",	"",
		"_COMMAND + KEY", 																"", "",
		"0RETURN", 				"save essay (or note) and exit editor", 					"",
		"0[ or ]",				"edit the prior or next essay (or note)",					"",
		"0S",					"save the note or essay",									"",
		"",																				"",	"",
		"!KEYS, WHEN NO NOTES ARE GRABBED", 											"", "",
		"",																				"",	"",
		"_COMMAND + KEY", 																"", "",
		"0N",					"swap between essay and note",								"",
		"",																				"",	"",
		"",																				"",	"",
		"!WHEN ONE OR MORE NOTES ARE GRABBED", 											"", "",
		"",																				"",	"",
		"_KEY",			 																"", "",
		"0ARROWS (up/down)",	"grab a different note", 									"",
		"0N",					"swap between essay and first of them",						"",
		"",																				"",	"",
		"_SHIFT + KEY",			 														"", "",
		"0ARROWS (up/down)",	"grab an additional note", 									"",
		"",																				"",	"",
		"_OPTION + KEY", 																"", "",
		"0DELETE", 				"erase and remove them",									"",
		"0ARROWS",		 		"move them", 												"",
		"",					 															"",	""
	]

}
