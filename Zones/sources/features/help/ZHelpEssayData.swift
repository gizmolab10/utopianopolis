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
		"",																						"",	"",
		"!GRAPHICS",																			"",	"",
		"",																						"",	"",
		"_drag dot",					"click to grab or ungrab the note",							"",
		".b",							"filled dot indicates note contains cursor or is grabbed",	"",
		"",																						"",	""
	]

	let essayColumnTwo: [String] = essayPrefixArray + [
		"",																						"",	"",
		"!KEYS, ALWAYS",					 													"", "",
		"",																						"",	"",
		"_KEY",			 																		"", "",
		"0ESCAPE", 						"discard changes and exit editor",		 					"",
		"",																						"",	"",
		"_COMMAND + KEY", 																		"", "",
		"0RETURN", 						"save essay (or note) and exit editor",						"",
		"0[ or ]",						"edit the prior or next essay (or note)",					"",
		"0S",							"save the note or essay",									"",
		"",																						"",	"",
		"",																						"",	"",
		"!KEYS, WHEN NO NOTES ARE GRABBED", 													"", "",
		"",																						"",	"",
		"_COMMAND + KEY", 																		"", "",
		"0N",							"swap between essay and note",								"",
		"",																						"",	"",
		"",																						"",	"",
		"!WHEN ONE OR MORE NOTES ARE GRABBED", 													"", "",
		"",																						"",	"",
		"_KEY",			 																		"", "",
		"0ARROWS (vertical)",			"grab a different note", 									"",
		"0ARROWS (vertical) + SHIFT",	"grab an additional note", 									"",
		"0ARROWS + OPTION",				"move them", 												"",
		"0DELETE", 						"erase and remove them",									"",
		"0N",							"swap between essay and the first grabbed note",			"",
		"",					 																	"",	""
	]

}
