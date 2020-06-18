//
//  ZHelpGraphData.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/4/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

class ZHelpGraphData : ZHelpData {

	override var columnStrings : [[String]] { return [graphColumnOne, graphColumnTwo, graphColumnThree, graphColumnFour] }
	override var tabOffsets    :  [Int]     { return [0, 20, 85] }
	override var columnWidth   :   Int      { return 288 }

	let graphColumnOne: [String] = [
		"",				"", 											"",
		"bEVERYWHERE:",	"", 											"",
		"",				"", 											"",
		"uKEY", 		"", 											"",
		" RETURN", 		"begin or end editing idea", 					"edit-d05d18996df7",
		" SPACE", 		"create new idea in list",    					"edit-d05d18996df7",
		" TAB", 		"create next idea", 							"edit-d05d18996df7",
		"",				"", 											"",
		"uCOMMAND + KEY", 											"", "",
		" RETURN", 		"begin/end editing note", 						"",
		"pCOMMA", 		"show or hide preferences", 					"help-inspector-view-c360241147f2",
		" A", 			"select all",	 								"",
		" P", 			"print the map (or this window)",   			"",
		"pY",			"toggle extent of breadcrumb list",				"",
		"",				"", 											"",
		"uCONTROL + KEY", 											"", "",
		"pCOMMA", 		"toggle navigation: un/confined", 				"",
		"pDELETE", 		"show trash", 									"organize-fcdc44ac04e4",
		"pPERIOD", 		"toggle lists grow up/down",		 			"",
		"p/", 			"remove current focus",				 			"focusing-your-thinking-a53adb16bba",
		"",				"", 											"",
		"uCOMMAND + OPTION + KEY", 									"", "",
		" RETURN", 		"begin editing note",							"",
		" /", 			"show or hide this window", 					"",
		" A", 			"show About Seriously", 						"",
		" R", 			"report a problem", 							"",
		"pX",			"clear recents",								"",
		"pY",			"show or hide necklace tooltips",				"",
		"",				"", 											"",
		"i",			"", 											"",
		"bWHILE IN THE SEARCH BAR:", 								"", "",
		"",				"", 											"",
		"uKEY",			"", 											"",
		" RETURN", 		"perform search", 								"search-2a996591375a",
		" ESCAPE", 		"dismisss search bar", 							"search-2a996591375a",
		"",				"", 											"",
		"uCOMMAND + KEY", 											"", "",
		" A", 			"select all search text", 						"search-2a996591375a",
		" F", 			"dismisss search bar", 							"search-2a996591375a",
		"",				"", 											"",
	]

	let graphColumnTwo: [String] = [
		"",				"", 											"",
		"bWHILE EDITING AN IDEA:", 									"", "",
		"",				"", 											"",
		"uKEY",			"", 											"",
		" ESCAPE", 		"cancel edit, discarding changes", 				"edit-d05d18996df7",
		"",				"", 											"",
		"uCOMMAND + KEY", 											"", "",
		" PERIOD", 		"cancel edit, discarding changes", 				"edit-d05d18996df7",
		" A", 			"select all text", 								"edit-d05d18996df7",
		"pI", 			"show extra characters popup menu", 			"",
		"p",			"", 											"",
		"UCOMMAND + OPTION + KEY", 									"", "",
		"pPERIOD", 		"toggle lists grow up/down,",					"",
		"p", 			"(and) move idea up/down", 						"organize-fcdc44ac04e4",
		"p",			"", 											"",
		"uCONTROL+ KEY", 											"", "",
		" SPACE", 		"create new idea in list", 						"edit-d05d18996df7",
		"",				"", 											"",
		"",				"", 											"",
		"bWHILE EDITING (TEXT IS SELECTED):", 						"", "",
		"",				"", 											"",
		"psurround:", 	"| [ { ( < \" ' SPACE",							"edit-d05d18996df7",
		"p",			"", 											"",
		"uCOMMAND + KEY", 											"", "",
		"pD", 			"if all selected, append to parent", 			"parent-child-tweaks-bf067abdf461",
		"p ", 			"if not all selected, add to list", 			"parent-child-tweaks-bf067abdf461",
		" L", 			"convert to lowercase", 						"edit-d05d18996df7",
		" U", 			"convert to uppercase", 						"edit-d05d18996df7",
		"",				"", 											"",
		"i",			"", 											"",
		"bWHILE IN THE SEARCH RESULTS:", 							"", "",
		"",				"", 											"",
		"uKEY",			"", 											"",
		" RETURN", 		"focus on selected result", 					"search-2a996591375a",
		"",				"", 											"",
		"uARROW KEY",	"", 											"",
		" LEFT", 		"exit search", 									"search-2a996591375a",
		" RIGHT", 		"focus on selected result", 					"search-2a996591375a",
		" vertical", 	"browse results (wraps around)", 				"search-2a996591375a",
		"",				"", 											"",
	]

	let graphColumnThree: [String] = [
		"",				"", 											"",
		"bWHILE NAVIGATING (SINGLE IDEA SELECTED, NOT BEING EDITED):", "", "",
		"",				"", 											"",
		"pmark:", 		"" + kMarkingCharacters, 						"extras-2a9b1a7db21f",
		"p",			"", 											"",
		"uKEY",			"", 											"",
		" ARROWS", 		"navigate map", 								"",
		"pCOMMA", 		"switch confined with unconfined", 				"",
		" DELETE", 		"selected ideas and their lists",	 			"organize-fcdc44ac04e4",
		"pHYPHEN", 		"add 'line', or un/title it", 					"lines-37426469b7c6",
		"pPERIOD", 		"toggle lists grow up/down", 					"",
		" SPACE", 		"create an idea", 								"edit-d05d18996df7",
		" /", 			"focus (also, manage favorite)", 				"focusing-your-thinking-a53adb16bba",
		" \\", 			"switch to other map", 				    		"",
		"p'", 			"switch recents with favorites",				"focusing-your-thinking-a53adb16bba",
		" [", 			"focus on prior idea", 							"focusing-your-thinking-a53adb16bba",
		" ]", 			"focus on next idea",         					"focusing-your-thinking-a53adb16bba",
		"p=", 			"invoke hyperlink or email", 					"extras-2a9b1a7db21f",
		"pB", 			"create a bookmark", 							"focusing-your-thinking-a53adb16bba",
		" C", 			"recenter the map", 							"",
		" D", 			"duplicate", 									"",
		"pE", 			"create/edit email address",					"extras-2a9b1a7db21f",
		" F", 			"search", 										"search-2a996591375a",
		"pG", 			"refetch selection's list",		 				"cloud-vs-file-f3543f7281ac",
		"pH", 			"create/edit hyperlink", 						"extras-2a9b1a7db21f",
		"pK", 			"un/color the text", 							"extras-2a9b1a7db21f",
		" L", 			"convert to lowercase", 						"edit-d05d18996df7",
		" N",			"create/edit note",								"",
		"pO", 			"import from a Seriously file", 				"cloud-vs-file-f3543f7281ac",
		" R", 			"reverse order of list", 						"organize-fcdc44ac04e4",
		"pS", 			"save to a Seriously file", 					"cloud-vs-file-f3543f7281ac",
		"pT", 			"swap selected idea with parent", 				"parent-child-tweaks-bf067abdf461",
		" U", 			"convert to uppercase", 						"edit-d05d18996df7",
		"",				"", 											"",
		"uCOMMAND + OPTION + KEY", 									"", "",
		" DELETE", 		"permanently (not into trash)", 				"organize-fcdc44ac04e4",
		"pHYPHEN", 		"convert titled line to/from parent",		 	"lines-37426469b7c6",
		"pO", 			"show data files in Finder", 					"cloud-vs-file-f3543f7281ac",
		" S", 			"save to cloud",			 					"cloud-vs-file-f3543f7281ac",
		"",				"", 											"",
		"p",            "INDICATES PRO FEATURE",						"",
	]

	let graphColumnFour: [String] = [
		"",				"", 											"",
		"",				"", 											"",
		"uOPTION + KEY", 											"", "",
		" ARROWS", 		"move selected idea", 							"organize-fcdc44ac04e4",
		"pDELETE", 		"retaining current list",						"organize-fcdc44ac04e4",
		"pRETURN", 		"edit with cursor at end", 						"edit-d05d18996df7",
		"pHYPHEN", 		"convert text to/from 'titled line'", 			"lines-37426469b7c6",
		" TAB", 		"new idea containing", 							"edit-d05d18996df7",
		"pG", 			"refetch all lists within selection", 	 		"cloud-vs-file-f3543f7281ac",
		"pS", 			"export to a outline file", 					"cloud-vs-file-f3543f7281ac",
		"",				"", 											"",
		"uCOMMAND + KEY", 											"", "",
		"pARROWS", 		"extend all the way", 							"selecting-ideas-cc2939720e53",
		" HYPHEN", 		"reduce font size", 							"",
		" +", 		    "increase font size", 							"",
		" /", 			"refocus current favorite", 					"focusing-your-thinking-a53adb16bba",
		" A", 			"select all ideas", 							"selecting-ideas-cc2939720e53",
		"pD", 			"append onto parent", 							"parent-child-tweaks-bf067abdf461",
		"pG", 			"refetch entire map",   						"cloud-vs-file-f3543f7281ac",
		"",				"", 											"",
		"uMOUSE CLICK + KEY",										"", "",
		" COMMAND", 	"drag entire map", 							    "mouse-e21b7a63020e",
		" SHIFT", 		"un/extend selection", 							"selecting-ideas-cc2939720e53",
		"",				"", 											"",
		"uSHIFT + ARROW KEY (+ COMMAND: all)",	 					"", "",
		" LEFT ", 		"hide list", 									"focusing-your-thinking-a53adb16bba",
		" RIGHT", 		"reveal list",	 								"focusing-your-thinking-a53adb16bba",
		" vertical", 	"extend selection", 							"selecting-ideas-cc2939720e53",
		"",				"", 											"",
		"",				"", 											"",
		"BMULTIPLE IDEAS SELECTED:", 											"", "",
		"p",			"", 											"",
		"UKEY",			"", 											"",
		"pHYPHEN", 		"first idea is titled line -> group", 			"lines-37426469b7c6",
		"p#", 			"mark with ascending numbers", 					"extras-2a9b1a7db21f",
		"pA", 			"a to z (+ OPTION: z to a)", 					"organize-fcdc44ac04e4",
		"pM", 			"by length (+ OPTION: reverse)", 				"organize-fcdc44ac04e4",
		"pR", 			"reverse",		 								"organize-fcdc44ac04e4",
		"",				"", 											"",
	]
}