//
//  ZHelpNotesData.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZHelpEssayData: ZHelpData {

	override var columnStrings : [[String]] { return [mapColumnOne, mapColumnTwo, mapColumnThree, mapColumnFour] }
	override var tabOffsets    :  [Int]     { return [0, 20, 85] }
	override var columnWidth   :   Int      { return 288 }

	let mapColumnOne: [String] = [
		"",				"", 												"",
		"!EVERYWHERE:",	"", 												"",
		"",				"", 												"",
		"_KEY", 		"", 												"",
		"0RETURN", 		"begin or end editing idea", 						"edit-d05d18996df7",
		"0SPACE", 		"create new idea in list",    						"edit-d05d18996df7",
		"0TAB", 		"create next idea", 								"edit-d05d18996df7",
		"",				"", 												"",
		"_COMMAND + KEY", 												"", "",
		"2RETURN", 		"begin/end editing note", 							"",
		"2COMMA", 		"show or hide preferences", 						"help-inspector-view-c360241147f2",
		"0A", 			"select all",	 									"",
		"1P", 			"print the map (or this window)",   				"",
		"0Y",			"enable/disable tooltips",							"",
		"2",			"", 												"",
		"2_CONTROL + KEY", 												"", "",
		"2COMMA", 		"toggle lists grow up/down", 						"",
		"2DELETE", 		"show trash", 										"organize-fcdc44ac04e4",
		"2PERIOD", 		"toggle navigation: un/confined",		 			"",
		"2/", 			"remove current focus",					 			"focusing-your-thinking-a53adb16bba",
		"",				"", 												"",
		"_COMMAND + OPTION + KEY", 										"", "",
		"2RETURN", 		"begin editing note",								"",
		"0/", 			"show/hide this window", 							"",
		"0A", 			"show About Seriously", 							"",
		"0R", 			"report a problem", 								"",
		"2X",			"clear recents",									"",
		"",				"", 												"",
		"",				"", 												"",
		"+",			"", 												"",
		"!WHILE IN THE SEARCH BAR:", 									"", "",
		"",				"", 												"",
		"_KEY",			"", 												"",
		"0RETURN", 		"perform search", 									"search-2a996591375a",
		"0ESCAPE", 		"dismisss search bar", 								"search-2a996591375a",
		"",				"", 												"",
		"_COMMAND + KEY", 												"", "",
		"0A", 			"select all search text", 							"search-2a996591375a",
		"0F", 			"dismisss search bar", 								"search-2a996591375a",
		"",				"", 												"",
		"",				"", 												"",
		"0Legend:",														"", "",
	]

	let mapColumnTwo: [String] = [
		"",				"", 												"",
		"!WHILE EDITING AN IDEA:", 										"", "",
		"",				"", 												"",
		"_KEY",			"", 												"",
		"0ESCAPE", 		"cancel edit, discarding changes", 					"edit-d05d18996df7",
		"",				"", 												"",
		"_COMMAND + KEY", 												"", "",
		"0PERIOD", 		"cancel edit, discarding changes", 					"edit-d05d18996df7",
		"0A", 			"select all text", 									"edit-d05d18996df7",
		"2I", 			"show specials popup menu", 			        	"",
		"",			    "", 												"",
		"2_COMMAND + OPTION + KEY", 										"", "",
		"2COMMA", 		"toggle lists grow up/down", 						"",
		"2", 			"(and) move idea up/down", 							"organize-fcdc44ac04e4",
		"2",			"", 												"",
		"1_CONTROL + KEY","", 												"",
		"1SPACE", 		"create new idea in list", 							"edit-d05d18996df7",
		"",				"", 												"",
		"",				"", 												"",
		"1!WHILE EDITING (TEXT IS SELECTED):", 							"", "",
		"",				"", 												"",
		"2surround:", 	"| [ { ( < \" ' SPACE",								"edit-d05d18996df7",
		"2",			"", 												"",
		"1_COMMAND + KEY", 												"", "",
		"2D", 			"if all selected, append to parent", 				"parent-child-tweaks-bf067abdf461",
		"2 ", 			"if not all selected, add to list",		 			"parent-child-tweaks-bf067abdf461",
		"1L", 			"convert to lowercase", 							"edit-d05d18996df7",
		"1U", 			"convert to uppercase", 							"edit-d05d18996df7",
		"",				"", 												"",
		"+",			"", 												"",
		"!WHILE IN THE SEARCH RESULTS:", 								"", "",
		"",				"", 												"",
		"_KEY",			"", 												"",
		"0RETURN", 		"focus on selected result", 						"search-2a996591375a",
		"",				"", 												"",
		"_ARROW KEY",	"", 												"",
		"0LEFT", 		"exit search", 										"search-2a996591375a",
		"0RIGHT", 		"focus on selected result", 						"search-2a996591375a",
		"0vertical", 	"browse results (wraps around)", 					"search-2a996591375a",
		"",				"", 												"",
		"",				"", 												"",
		"0",	    	"IN BLUE: CLICK TO READ MORE",						"-",
	]

	let mapColumnThree: [String] = [
		"",				"", 												"",
		"!WHILE NAVIGATING (SINGLE IDEA SELECTED, NOT BEING EDITED):",	"", "",
		"",				"", 												"",
		"2mark:", 		kMarkingCharacters, 								"extras-2a9b1a7db21f",
		"2",			"", 												"",
		"_KEY",			"", 												"",
		"0ARROWS", 		"navigate map", 									"",
		"0DELETE", 		"selected ideas and their lists",		 			"organize-fcdc44ac04e4",
		"2HYPHEN", 		"add 'line', or un/title it", 						"lines-37426469b7c6",
		"2PERIOD", 		"toggle navigation: un/confined",		 			"",
		"2EQUALS", 		"invoke hyperlink or email", 						"extras-2a9b1a7db21f",
		"2COMMA", 		"toggle lists grow up/down", 						"",
		"0SPACE", 		"create an idea", 									"edit-d05d18996df7",
		"0/", 			"focus (also, manage favorite)", 					"focusing-your-thinking-a53adb16bba",
		"0\\", 			"switch to other map", 				    			"",
		"2'", 			"switch recents with favorites",					"focusing-your-thinking-a53adb16bba",
		"1[", 			"focus on prior idea", 								"focusing-your-thinking-a53adb16bba",
		"1]", 			"focus on next idea",         						"focusing-your-thinking-a53adb16bba",
		"2B", 			"create a bookmark", 								"focusing-your-thinking-a53adb16bba",
		"1C", 			"recenter the map", 								"",
		"1D", 			"duplicate", 										"",
		"2E", 			"create/edit email address",						"extras-2a9b1a7db21f",
		"0F", 			"search", 											"search-2a996591375a",
		"2G", 			"refetch selection's list",		 					"cloud-vs-file-f3543f7281ac",
		"2H", 			"create/edit hyperlink", 							"extras-2a9b1a7db21f",
		"2K", 			"un/color the text", 								"extras-2a9b1a7db21f",
		"1L", 			"convert to lowercase", 							"edit-d05d18996df7",
		"1N",			"create/edit note",									"",
		"2O", 			"import from a Seriously file",	 					"cloud-vs-file-f3543f7281ac",
		"1R", 			"reverse order of list", 							"organize-fcdc44ac04e4",
		"2S", 			"save to a Seriously file", 						"cloud-vs-file-f3543f7281ac",
		"2T", 			"swap selected idea with parent", 					"parent-child-tweaks-bf067abdf461",
		"1U", 			"convert to uppercase", 							"edit-d05d18996df7",
		"",				"", 												"",
		"2_COMMAND + OPTION + KEY", 									"", "",
		"2DELETE", 		"permanently (not into trash)", 					"organize-fcdc44ac04e4",
		"2HYPHEN", 		"convert titled line to/from parent",			 	"lines-37426469b7c6",
		"2O", 			"show data files in Finder", 						"cloud-vs-file-f3543f7281ac",
		"2S", 			"save to cloud",			 						"cloud-vs-file-f3543f7281ac",
		"",				"", 												"",
		"",				"", 												"",
		//		"2",			"PRO FEATURE",										"",
	]

	let mapColumnFour: [String] = [
		"",				"", 												"",
		"",				"", 												"",
		"",				"", 												"",
		"_OPTION + KEY","", 												"",
		"0ARROWS", 		"move selected idea", 								"organize-fcdc44ac04e4",
		"2DELETE", 		"retaining current list",							"organize-fcdc44ac04e4",
		"2RETURN", 		"edit with cursor at end", 							"edit-d05d18996df7",
		"2HYPHEN", 		"convert text to/from 'titled line'", 				"lines-37426469b7c6",
		"1TAB", 		"new idea containing", 								"edit-d05d18996df7",
		"2'", 			"move ideas between small maps",					"",
		"2G", 			"refetch all lists within selection", 	 			"cloud-vs-file-f3543f7281ac",
		"2S", 			"export to a outline file", 						"cloud-vs-file-f3543f7281ac",
		"1",			"", 												"",
		"1_COMMAND + KEY", 												"", "",
		"2ARROWS", 		"extend all the way", 								"selecting-ideas-cc2939720e53",
		"1HYPHEN", 		"reduce font size", 								"",
		"1EQUALS", 	    "increase font size", 								"",
		"1/", 			"refocus current favorite", 						"focusing-your-thinking-a53adb16bba",
		"1A", 			"select all ideas", 								"selecting-ideas-cc2939720e53",
		"2D", 			"append onto parent", 								"parent-child-tweaks-bf067abdf461",
		"2G", 			"refetch entire map",   							"cloud-vs-file-f3543f7281ac",
		"1",			"", 												"",
		"_MOUSE CLICK + KEY",											"", "",
		"0COMMAND", 	"drag entire map", 								    "mouse-e21b7a63020e",
		"1SHIFT", 		"un/extend selection", 								"selecting-ideas-cc2939720e53",
		"",				"", 												"",
		"_SHIFT + ARROW KEY (+ COMMAND: all)",	 						"", "",
		"0LEFT ", 		"hide list", 										"focusing-your-thinking-a53adb16bba",
		"0RIGHT", 		"reveal list",	 									"focusing-your-thinking-a53adb16bba",
		"2vertical", 	"extend selection", 								"selecting-ideas-cc2939720e53",
		"",				"", 												"",
		"2!MULTIPLE IDEAS SELECTED:", 									"", "",
		"2",			"", 												"",
		"2_KEY",		"", 												"",
		"2HYPHEN", 		"first idea is titled line -> group",	 			"lines-37426469b7c6",
		"2#", 			"mark with ascending numbers", 						"extras-2a9b1a7db21f",
		"2A", 			"a to z (+ OPTION: z to a)", 						"organize-fcdc44ac04e4",
		"2M", 			"by length (+ OPTION: reverse)", 					"organize-fcdc44ac04e4",
		"2R", 			"reverse",		 									"organize-fcdc44ac04e4",
	]
}
