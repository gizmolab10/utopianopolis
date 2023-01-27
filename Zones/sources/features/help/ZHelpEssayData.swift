//
//  ZHelpNotesData.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

let essayPrefixArray = Array(repeating: kEmpty, count: 3 * 13)

class ZHelpEssayData: ZHelpData {

	override var noTabPrefix   :  String        { return "                    " }
	override var columnStrings : [StringsArray] { return [essayColumnOne, essayColumnTwo] }
	override var tabOffsets    : [Int]          { return [0, 20, 180] }
	override var rowHeight     :  CGFloat       { return 14.0 }
	override var dotOffset     :  CGFloat       { return  2.3 }    

	let essayColumnOne: StringsArray = essayPrefixArray + [
		"",																							"",	"",
		"!GRAPHICS",																				"",	"",
		"",																							"",	"",
		"_drag dot",					"filled dot indicates note contains cursor or is grabbed",		"",
		".b",							"click to grab or ungrab the note",								"",
		"",																							"",	"",
		"_reveal dot",					"two tiny dots inside indicates a note or essay",				"",
		".f",							"in maps: COMMAND-click it to edit the note or essay",			"",
		"",																							"",	""
	]

	let essayColumnTwo: StringsArray = essayPrefixArray + [
		"",																							"",	"",
		"!ALWAYS",									 												"",	"",
		"",																							"",	"",
		"_KEY",			 																			"", "",
		"0ESCAPE", 						"discard unsaved changes and exit the editor",			 		"",
		"",																							"",	"",
		"_COMMAND + KEY", 																			"", "",
		"0RETURN", 						"save changes and exit the editor",								"",
		"0[ or ]",						"save changes and edit the prior or next essay / note",			"",
		"0D",							"convert selected text into child note",						"",
		"0J",							"add boilerplate to empty notes (use OPTION to remove)",		"",
		"0N",							"save changes and toggle between essay and note",				"",
		"0S",							"save changes",													"",
		"0T",							"lookup selection in thesaurus",								"",
		"",																							"",	"",
		"_COMMAND + OPTION + CONTROL + KEY", 														"", "",
		"0LEFT ARROW", 					"edit the containing essay",									"",
		"",																							"",	"",
		"",																							"",	"",
		"!WHEN ONE OR MORE NOTES ARE GRABBED (e.g., see bottom left)", 								"", "",
		"",																							"",	"",
		"_KEY",			 																			"", "",
		"0ESCAPE", 						"ungrab them",			 										"",
		"0DELETE", 						"destroy and remove them",										"",
		"0EQAUALS",						"grab selected text, or clear grab",							"",
		"0ARROWS (vertical)",			"grab a different note", 										"",
		"0ARROWS (vertical) + SHIFT",	"grab an additional note", 										"",
		"0ARROWS + OPTION",				"move them", 													"",
		"0LEFT ARROW",					"if top is grabbed: save changes and exit the editor",			"",
		"0         ",					"else: same as N, below",										"",
		"0N",							"save changes and swap between essay and first grabbed note",	"",
		"",					 																		"",	""
	]

}
