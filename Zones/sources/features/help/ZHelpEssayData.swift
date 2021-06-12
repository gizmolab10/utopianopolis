//
//  ZHelpNotesData.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

let essayPrefixArray = Array(repeating: kEmpty, count: 3 * 14)

class ZHelpEssayData: ZHelpData {

	override var noTabPrefix   :  String        { return "                    " }
	override var columnStrings : [StringsArray] { return [essayColumnOne, essayColumnTwo] }
	override var tabOffsets    : [Int]          { return [0, 20, 180] }
	override var rowHeight     :  CGFloat       { return 14.55 }

	let essayColumnOne: StringsArray = essayPrefixArray + [
		"",																								"",	"",
		"!GRAPHICS",																					"",	"",
		"",																								"",	"",
		"_drag dot",					"filled dot indicates note contains cursor or is grabbed",			"",
		".b",							"click to grab or ungrab the note",									"",
		"0        ",					"double-click to toggle between note and essay",					"",
		"",																								"",	"",
		"_reveal dot",					"in maps: COMMAND-click it to edit the note or essay, when it ...",	"",
		".f",							"has two tiny dots inside",											"",
		"",																								"",	""
	]

	let essayColumnTwo: StringsArray = essayPrefixArray + [
		"",																								"",	"",
		"!KEYS, ALWAYS",							 													"", "",
		"",																								"",	"",
		"_KEY",			 																				"", "",
		"0ESCAPE", 						"discard unsaved changes and exit the editor",			 			"",
		"",																								"",	"",
		"_COMMAND + KEY", 																				"", "",
		"0RETURN", 						"save changes and exit the editor",									"",
		"0[ or ]",						"save changes and edit the prior or next essay (or note)",			"",
		"0S",							"save changes",														"",
		"0T",							"lookup selection in thesaurus",									"",
		"",																								"",	"",
		"_COMMAND + OPTION + CONTROL + KEY", 															"", "",
		"0LEFT ARROW", 					"edit the containing essay",										"",
		"",																								"",	"",
		"",																								"",	"",
		"!KEYS, WHEN NO NOTES ARE GRABBED",			 													"", "",
		"",																								"",	"",
		"_COMMAND + KEY", 																				"", "",
		"0N",							"save changes and toggle between essay and note",					"",
		"",																								"",	"",
		"",																								"",	"",
		"!WHEN ONE OR MORE NOTES ARE GRABBED (e.g., see bottom left)", 									"", "",
		"",																								"",	"",
		"_KEY",			 																				"", "",
		"0ESCAPE", 						"ungrab them",			 											"",
		"0DELETE", 						"destroy and remove them",											"",
		"0EQAUALS",						"grab selected text, or clear grab",								"",
		"0ARROWS (vertical)",			"grab a different note", 											"",
		"0ARROWS (vertical) + SHIFT",	"grab an additional note", 											"",
		"0ARROWS + OPTION",				"move them", 														"",
		"0LEFT ARROW",					"if top is grabbed: save changes and exit the editor",				"",
		"0         ",					"else: same as N, below",											"",
		"0N",							"save changes and swap between essay and first grabbed note",		"",
		"",					 																			"",	""
	]

}
