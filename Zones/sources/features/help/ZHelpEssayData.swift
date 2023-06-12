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

	override var columnStrings : [StringsArray] { return [essayColumnOne, essayColumnTwo] }
	override var noTabPrefix   :  String        { return "                    " }
	override var tabOffsets    :  IntArray      { return [0, 20, 220] }
	override var rowHeight     :  CGFloat       { return 14.0 }
	override var dotOffset     :  CGFloat       { return  2.3 }    

	let essayColumnOne: StringsArray = essayPrefixArray + [
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
		"!ALWAYS",									 												"",	"",
		"",																							"",	"",
		"_KEY",			 																			"", "",
		" ESCAPE", 						"discard unsaved changes & exit the editor",			 		"",
		"",																							"",	"",
		"_LEFT ARROW KEY", 																			"", "",
		" COMMAND + OPTION",			"edit the parent essay",										"",
		"",																							"",	"",
		"_RIGHT ARROW KEY", 																		"", "",
		" COMMAND + OPTION",			"hide the parent essay",										"",
		" COMMAND + CONTROL",			"create children (notes) from paragraphs in selected text",		"",
		" COMMAND + CONTROL + OPTION",	"   \"       \"        \"     from sentences   \"    \"    \"",	"",
		"",																							"",	"",
		"_COMMAND + KEY", 																			"", "",
		" DELETE", 						"remove note cursor is in",										"",
		" RETURN", 						"save changes & exit the editor",								"",
		" [ or ]",						"save changes & edit the prior or next essay / note",			"",
		" D",							"save changes & convert selected text into child note",			"",
		" J",							"add boilerplate to empty notes (use OPTION to remove)",		"",
		" N",							"save changes & toggle between essay & note",					"",
		" S",							"save changes",													"",
		" T",							"lookup selection in thesaurus",								"",
		"",																							"",	"",
		"",																							"",	"",
		"!WHEN ONE OR MORE NOTES ARE GRABBED (e.g., see bottom left)", 								"", "",
		"",																							"",	"",
		"_KEY",			 																			"", "",
		" ESCAPE", 						"ungrab them",			 										"",
		" DELETE", 						"destroy & remove them",										"",
		" EQAUALS",						"grab selected text, or clear grab",							"",
		" RETURN + OPTION", 			"ungrab and then select text of note",							"",
		" ARROWS + OPTION",				"move grabbed notes", 											"",
		" ARROWS (vertical)",			"grab a different note", 										"",
		" ARROWS (vertical) + SHIFT",	"grab an additional note", 										"",
		" LEFT ARROW",					"if top is grabbed: save changes & exit the editor",			"",
		"i         ",					"else: same as N, below",										"",
		" N",							"save changes & swap between essay & first grabbed note",		"",
		"",					 																		"",	""
	]

	var explanationOfEssayControls: String {
		return ["           1               2          3         4         5          6          7              8            9",
		kEmpty,
		"1     arrows take you to prior and next note/essay",
		"2     save all changes and resume editing",
		"3     print entire note/essay",
		"4     save all changes and exit the editor",
		"5     delete the note the cursor is in",
		"6     discard all changes and exit the editor",
		"7     hide titles (idea text) grab dots",
		"8     show titles and hide grab dots",
		"9     show both"].joinedWithNewLine
	}
}
