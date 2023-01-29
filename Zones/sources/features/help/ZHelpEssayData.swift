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
	override var tabOffsets    : [Int]          { return [0, 20, 220] }
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
		"0ESCAPE", 						"discard unsaved changes & exit the editor",			 		"",
		"",																							"",	"",
		"_LEFT ARROW KEY", 																			"", "",
		"0COMMAND + OPTION",			"edit the containing essay",									"",
		"",																							"",	"",
		"_RIGHT ARROW KEY", 																		"", "",
		"0COMMAND + CONTROL",			"create children (notes) from selected paragraphs",				"",
		"0COMMAND + CONTROL + OPTION",	"create children (notes) from selected sentences",				"",
		"",																							"",	"",
		"_COMMAND + KEY", 																			"", "",
		"0RETURN", 						"save changes & exit the editor",								"",
		"0[ or ]",						"save changes & edit the prior or next essay / note",			"",
		"0D",							"save changes & convert selected text into child note",			"",
		"0J",							"add boilerplate to empty notes (use OPTION to remove)",		"",
		"0N",							"save changes & toggle between essay & note",					"",
		"0S",							"save changes",													"",
		"0T",							"lookup selection in thesaurus",								"",
		"",																							"",	"",
		"",																							"",	"",
		"!WHEN ONE OR MORE NOTES ARE GRABBED (e.g., see bottom left)", 								"", "",
		"",																							"",	"",
		"_KEY",			 																			"", "",
		"0ESCAPE", 						"ungrab them",			 										"",
		"0DELETE", 						"destroy & remove them",										"",
		"0EQAUALS",						"grab selected text, or clear grab",							"",
		"0ARROWS (vertical)",			"grab a different note", 										"",
		"0ARROWS (vertical) + SHIFT",	"grab an additional note", 										"",
		"0ARROWS + OPTION",				"move them", 													"",
		"0LEFT ARROW",					"if top is grabbed: save changes & exit the editor",			"",
		"0         ",					"else: same as N, below",										"",
		"0N",							"save changes & swap between essay & first grabbed note",		"",
		"",					 																		"",	""
	]

}
