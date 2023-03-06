//
//  ZHelpBigMapData.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/4/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

class ZHelpMapData : ZHelpData {

	override var columnStrings     : [StringsArray] { return [mapColumnOne, mapColumnTwo, mapColumnThree, mapColumnFour] }
	override var tabOffsets        : [Int]          { return [0, 12, 77] }
	override var columnWidth       :  Int           { return 288 }
	override var indexOfLastColumn :  Int           { return 3 }

	let mapColumnOne: StringsArray = [
		"0",			 												"", "",
		"0!EVERYWHERE IN MAPS:", 										"", "",
		"0",			 												"", "",
		"0_KEY", 		 												"", "",
		"0RETURN", 		"begin or end editing idea", 						"edit+b+edit-d05d18996df7",
		"0TAB", 		"create next idea", 								"edit+b+edit-d05d18996df7",
		"0",			 												"", "",
		"0_COMMAND + KEY", 												"", "",
		"2RETURN", 		"begin/end editing note", 							"",
		"0COMMA", 		"show / hide preferences", 							"details+i+help-inspector-view-c360241147f2",
		"0P", 			"print the map (or this window)",   				"",
		"0Y",			"enable/disable toolTips",							"",
		"2",			 												"", "",
		"2_CONTROL + KEY", 												"", "",
		"2COMMA", 		"toggle lists grow up/down", 						"",
		"2DELETE", 		"show trash", 										"organize+i+organize-fcdc44ac04e4",
		"2PERIOD", 		"toggle navigation: un/confined",		 			"",
		"2/", 			"remove current focus",					 			"focus+b+focusing-your-thinking-a53adb16bba",
		"0",			 												"", "",
		"0_COMMAND + OPTION + KEY", 									"", "",
		"2RETURN", 		"begin editing note",								"",
		"0/", 			"show/hide this window", 							"",
		"0A", 			"show About Seriously", 							"",
		"0R", 			"report a problem", 								"",
		"0",			 												"", "",
		"0_COMMAND + MOUSE CLICK",										"", "",
		"0 ",		 	"drag entire map", 								    "mouse+i+mouse-e21b7a63020e",
		"+",			 												"", "",
		"0!WHILE IN THE SEARCH BAR:", 									"", "",
		"0",			 												"", "",
		"0_KEY",		 												"", "",
		"0RETURN", 		"perform search", 									"search+i+search-2a996591375a",
		"0ESCAPE", 		"dismisss search bar", 								"search+i+search-2a996591375a",
		"0",			 												"", "",
		"0_COMMAND + KEY", 												"", "",
		"0A", 			"select all search text", 							"search+i+search-2a996591375a",
		"0F", 			"dismisss search bar", 								"search+i+search-2a996591375a",
	]

	let mapColumnTwo: StringsArray = [
		"0",			 												"", "",
		"0!WHILE EDITING AN IDEA:", 									"", "",
		"0",			 												"", "",
		"0_KEY",		 												"", "",
		"0ESCAPE", 		"cancel edit, discarding changes", 					"edit+b+edit-d05d18996df7",
		"0",			 												"", "",
		"0_COMMAND + KEY", 												"", "",
		"0PERIOD", 		"cancel edit, discarding changes", 					"edit+b+edit-d05d18996df7",
		"0A", 			"select all text", 									"edit+b+edit-d05d18996df7",
		"2I", 			"specials popup",			 			        	"",
		"0",		     												"", "",
		"2_COMMAND + OPTION + KEY", 									"", "",
		"2COMMA", 		"toggle lists grow up/down", 						"",
		"2 ", 			"& move idea up/down", 								"organize+i+organize-fcdc44ac04e4",
		"2T", 			"swap selected idea with parent", 					"parent+a+parent-child-tweaks-bf067abdf461",
		"2",			 												"", "",
		"1_CONTROL + KEY", 												"", "",
		"1SPACE", 		"create new idea in list", 							"edit+b+edit-d05d18996df7",
		"1",			 												"", "",
		"0",			 												"", "",
		"0!WHILE EDITING (TEXT IS SELECTED):", 							"",	"",
		"0",			 												"", "",
		"0surround:", 	"| [ { ( < \" '",									"edit+b+edit-d05d18996df7",
		"1",			 												"", "",
		"1_COMMAND + KEY", 												"", "",
		"2D", 			"if all selected, append to parent", 				"parent+a+parent-child-tweaks-bf067abdf461",
		"2 ", 			"else, convert selection into a child",	 			"parent+a+parent-child-tweaks-bf067abdf461",
		"1L, U",		"convert to lowercase, uppercase", 					"edit+b+edit-d05d18996df7",
		"2T",			"lookup selection in thesaurus",					"",
		"+",			 												"", "",
		"0!WHILE IN THE SEARCH RESULTS:", 								"", "",
		"0",			 												"", "",
		"0_KEY",		 												"", "",
		"0RETURN", 		"focus on selected result", 						"search+i+search-2a996591375a",
		"0",			 												"", "",
		"0_ARROW KEY",	 												"", "",
		"0LEFT", 		"exit search", 										"search+i+search-2a996591375a",
		"0RIGHT", 		"focus on selected result", 						"search+i+search-2a996591375a",
		"0vertical", 	"browse results (wraps around)", 					"search+i+search-2a996591375a",
		"0",			 												"", "",
		"0",			 												"", "",
		"0legend:", 	"click on sky blue text to view further details",	"_", // leave underscore (invisible): applies blue color to text
	]

	let mapColumnThree: StringsArray = [
		"0",			 												"", "",
		"0!WHILE NAVIGATING (SINGLE IDEA SELECTED, NOT BEING EDITED):",	"", "",
		"2",			 												"", "",
		"2mark:", 		kMarkingCharacters, 								"more+a+extras-2a9b1a7db21f",
		"0",			 												"", "",
		"0_KEY",		 												"", "",
		"0ARROWS", 		"browse map",	 									"",
		"0DELETE", 		"selected ideas & their lists",			 			"organize+i+organize-fcdc44ac04e4",
		"2HYPHEN", 		"add 'line', or un/title it", 						"lines+a+lines-37426469b7c6",
		"2PERIOD", 		"toggle navigation: un/confined",		 			"",
		"2EQUALS", 		"invoke hyperlink or email", 						"more+a+extras-2a9b1a7db21f",
		"2COMMA", 		"toggle lists grow up/down", 						"",
		"0SPACE", 		"create new idea in list", 							"edit+b+edit-d05d18996df7",
		"0/", 			"focus (also, manage favorites)", 					"focus+b+focusing-your-thinking-a53adb16bba",
		"0\\", 			"switch to other map", 				    			"",
		"0[, ]", 		"focus on prior/next idea",         				"focus+b+focusing-your-thinking-a53adb16bba",
		"0B", 			"create a bookmark", 								"focus+b+focusing-your-thinking-a53adb16bba",
		"0C", 			"recenter the map", 								"",
		"1D", 			"duplicate", 										"",
		"0F", 			"search", 											"search+i+search-2a996591375a",
		"2H", 			"popup: email, hyperlink",			 				"more+a+extras-2a9b1a7db21f",
		"0I",			"popup: capitalize, lower, upper", 					"edit+b+edit-d05d18996df7",
		"1K", 			"un/color the text", 								"more+a+extras-2a9b1a7db21f",
		"1N",			"create/edit note",									"",
		"2O", 			"import from a Seriously file",	 					"data+a+cloud-vs-file-f3543f7281ac",
		"1R", 			"reorder popup",		 							"organize+i+organize-fcdc44ac04e4",
		"2S", 			"save to a Seriously file", 						"data+a+cloud-vs-file-f3543f7281ac",
		"2T", 			"swap selected idea with parent", 					"parent+a+parent-child-tweaks-bf067abdf461",
		"0X", 			"move into done (creating it if missing)",			"",
		"0",			 												"", "",
		"0_SHIFT + KEY",												"", "",
		"2[, ]", 		"focus on prior/next idea in group",				"",
		"0LEFT ", 		"hide list", 										"focus+b+focusing-your-thinking-a53adb16bba",
		"0RIGHT", 		"reveal list",	 									"focus+b+focusing-your-thinking-a53adb16bba",
		"2vertical", 	"extend selection", 								"select+b+selecting-ideas-cc2939720e53",
		"1",			 												"", "",
		"1_SHIFT + MOUSE CLICK",										"", "",
		"1 ", 			"un/extend selection", 								"select+b+selecting-ideas-cc2939720e53",
	]

	let mapColumnFour: StringsArray = [
		"0",			 												"", "",
		"0",			 												"", "",
		"1",			 												"", "",
		"1_COMMAND + KEY", 												"", "",
		"2ARROWS", 		"extend all the way", 								"select+b+selecting-ideas-cc2939720e53",
		"1HYPHEN", 		"reduce font size", 								"",
		"1EQUALS", 	    "increase font size", 								"",
		"1/", 			"refocus current favorite", 						"focus+b+focusing-your-thinking-a53adb16bba",
		"1'", 			"switch between linear & circular",					"",
		"1A", 			"select all ideas", 								"select+b+selecting-ideas-cc2939720e53",
		"2D", 			"append onto parent", 								"parent+a+parent-child-tweaks-bf067abdf461",
		"2[, ]", 		"prior/next favorites list",						"",
		"0",			 												"", "",
		"0_OPTION + KEY", 												"", "",
		"0ARROWS", 		"move selected idea", 								"organize+i+organize-fcdc44ac04e4",
		"2DELETE", 		"retaining current list",							"organize+i+organize-fcdc44ac04e4",
		"2RETURN", 		"edit with cursor at end", 							"edit+b+edit-d05d18996df7",
		"2HYPHEN", 		"convert text to/from 'titled line'", 				"lines+a+lines-37426469b7c6",
		"2TAB", 		"new idea containing", 								"edit+b+edit-d05d18996df7",
		"2'", 			"move ideas between small maps",					"",
		"28",			"prefix with an arrow",								"",
		"2S", 			"export to a outline file", 						"data+a+cloud-vs-file-f3543f7281ac",
		"2",			 												"", "",
		"2_COMMAND + OPTION + KEY", 									"", "",
		"2DELETE", 		"permanently (not into trash)", 					"organize+i+organize-fcdc44ac04e4",
		"2HYPHEN", 		"convert titled line to/from parent",			 	"lines+a+lines-37426469b7c6",
		"2D", 			"duplicate idea only (ignore its list)",			"",
		"2O", 			"show data files in Finder", 						"data+a+cloud-vs-file-f3543f7281ac",
		"2S", 			"save to cloud",			 						"data+a+cloud-vs-file-f3543f7281ac",
		"2[, ]", 		"move bookmark to",									"",
		"2", 			"prior/next favorites list",						"",
		"2",			 												"", "",
		"2_COMMAND + OPTION + CONTROL + KEY", 							"", "",
		"2N", 			"convert list into a note",							"",
		"2",			 												"", "",
		"2",			 												"", "",
		"2!WHILE MULTIPLE IDEAS ARE SELECTED:",							"", "",
		"2",			 												"", "",
		"2_KEY",		"",													"",
		"2HYPHEN", 		"first idea is titled line -> group",	 			"lines+a+lines-37426469b7c6",
		"2PLUS",		"create favorites group",							"",
		"2#", 			"mark with ascending numbers", 						"more+a+extras-2a9b1a7db21f"
	]
}
