//
//  ZHelpNotesData.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

let essayPrefixArray = Array(repeating: "", count: 24)

class ZHelpEssayData: ZHelpData {

	override var noTabPrefix       :   String   { return "                    " }
	override var columnStrings     : [[String]] { return [essayColumnOne, essayColumnTwo] }
	override var tabOffsets        :   [Int]    { return [0, 20, 170] }
	override var boldFont          :   ZFont    { return kBoldFont }

	let essayColumnOne: [String] = essayPrefixArray + [
		"",																				"",	"",
		"!KEYS, WHEN NO NOTES ARE GRABBED", 											"", "",
		"",																				"",	"",
		"_COMMAND + KEY", 																"", "",
		"0RETURN", 				"save essay (or note) and exit editor", 					"",
		"0N",					"swap between essay and note",								"",
		"",																				"",	"",
		"",																				"",	"",
		"!WHEN ONE OR MORE NOTES ARE GRABBED", 											"", "",
		"",																				"",	"",
		"_KEY",			 																"", "",
		"0ARROWS (up/down)",	"grab a different note", 									"",
		"",																				"",	"",
		"_SHIFT + KEY",			 														"", "",
		"0ARROWS (up/down)",	"grab an additional note", 									"",
		"",																				"",	"",
		"_OPTION + KEY", 																"", "",
		"0DELETE", 				"erase and remove them",									"",
		"0ARROWS",		 		"move them", 												"",
		"",					 															"",	""
	]

	let essayColumnTwo: [String] = essayPrefixArray + [
		"",																				"",	"",
		"!GRAPHICS",																	"",	"",
		"",																				"",	"",
		"_drag dot",			"click to grab the note",									"",
		".b",					"filled dot indicates note is grabbed or contains cursor",	"",
		"",																				"",	""
	]

}
