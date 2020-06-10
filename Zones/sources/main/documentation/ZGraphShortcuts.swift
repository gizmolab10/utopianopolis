//
//  ZGraphShortcuts.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/4/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

class ZGraphShortcuts : ZDocumentation, ZGeneric {

	override var countOfRows       :  Int  { return max(graphColumnOne.count, max(graphColumnTwo.count, max(graphColumnThree.count, graphColumnFour.count))) / countPerRow }
	override var columnWidth       :  Int  { return 290 }

	func strippedStrings(for column: Int) -> [String] {
		let columnStrings = [graphColumnOne, graphColumnTwo, graphColumnThree, graphColumnFour]
		let    rawStrings = columnStrings[column]
		var        result = [String]()
		let         count = rawStrings.count / countPerRow
		var         index = 0

		while    index < count {
			let offset = index * countPerRow
			let  first = rawStrings[offset]
			let second = rawStrings[offset + 1]
			let  third = rawStrings[offset + 2]
			let   type = ZShortcutType(rawValue: first.substring(with: NSMakeRange(0, 1))) // grab first character
			index     += 1

			if      gProSkillLevel || type != .pro {
				if  gProSkillLevel || type != .insert {
					result.append(first)
					result.append(second)
					result.append(third)
				} else {
					while result.count < 93 {
						result.append("")
					}
				}
			}
		}

		return result
	}

	override func strings(for row: Int, column: Int) -> (String, String, String) {
		let strings = strippedStrings(for: column)
		let   index = row * countPerRow

		return index >= strings.count ? ("", "", "") : (strings[index], strings[index + 1], strings[index + 2])
	}

	override func attributedString(for row: Int, column: Int) -> NSMutableAttributedString {
		var (first, second, url) = strings(for: row, column: column)
		let     rawChar = first.substring(with: NSMakeRange(0, 1))
		let       lower = rawChar.lowercased()
		let       SHIFT = lower != rawChar
		let        type = ZShortcutType(rawValue: lower) // grab first character
		let   removable = SHIFT || type == .pro
		let        main = first.substring(fromInclusive: 1)             // grab remaining characters
		var  attributes = ZAttributesDictionary ()
		let      hasURL = !url.isEmpty
		var      prefix = "   "

		if !gProSkillLevel {
			if  removable {
				return NSMutableAttributedString(string: kTab + kTab + kTab)
			}
		}

		switch type {
			case .bold?:
				attributes[.font] = kBoldFont
			case .append?, .underline?:
				attributes[.underlineStyle] = 1
			case .plain?, .pro?:
				if  hasURL {
					attributes[.foregroundColor] = hyperlinkColor
					second.append(kSpace + kEllipsis)
				}

				fallthrough

			default:
				prefix = kTab		// for empty lines, including after last row
		}

		let result = NSMutableAttributedString(string: prefix)

		if  type == .plain {
			result.append(NSAttributedString(string: main))
		} else {
			if  gProSkillLevel,
				type == .pro {
				attributes[.backgroundColor] = powerUserColor
			}

			result.append(NSAttributedString(string: main, attributes: attributes))
		}

		if  second.length > 3 {
			result.append(NSAttributedString(string: kTab))
			result.append(NSAttributedString(string: second, attributes: attributes))
		}

		if  main.length + second.length < 11 && row != 1 && type != .plain {
			result.append(NSAttributedString(string: kTab)) 	// KLUDGE to fix bug in first column where underlined "KEY" doesn't have enough final tabs
		}

		result.append(NSAttributedString(string: kTab))

		return result
	}

	let graphColumnOne: [String] = [
		"",				"", "",
		"bEVERYWHERE:",	"", "",
		"",				"", "",
		"uKEY", 		"", "",
		" RETURN", 		"begin or end editing idea", 					"edit-d05d18996df7",
		" SPACE", 		"create child idea",    						"edit-d05d18996df7",
		" TAB", 		"create next idea", 							"edit-d05d18996df7",
		"",				"", "",
		"uKEY + COMMAND",		"", "",
		" RETURN", 		"begin or end editing hidden note", 			"",
		"pCOMMA", 		"show or hide preferences", 					"help-inspector-view-c360241147f2",
		" A", 			"select all",	 								"",
		" P", 			"print the map (or this window)",   			"",
		"pY",			"toggle extent of breadcrumb list",				"",
		"",				"", "",
		"uKEY + CONTROL",		"", "",
		"pCOMMA", 		"toggle navigation: un/confined", 				"",
		"pDELETE", 		"show trash", 									"organize-fcdc44ac04e4",
		"pPERIOD", 		"toggle lists grow up/down",		 			"",
		" SPACE", 		"create an idea", 								"edit-d05d18996df7",
		"p/", 			"remove current focus from recents", 			"focusing-your-thinking-a53adb16bba",
		"",				"", "",
		"uKEY + COMMAND + OPTION", "", "",
		" RETURN", 		"begin editing hidden note",					"",
		" /", 			"show or hide this window", 					"",
		" A", 			"show About Seriously", 						"",
		" R", 			"report a problem", 							"",
		"pX",			"clear recents",								"",
		"pY",			"show or hide necklace tooltips",				"",
		"",				"", "",
		"i",			"", "",
		"bWHILE IN THE SEARCH BAR:", "", "",
		"",				"", "",
		"uKEY",			"", "",
		" RETURN", 		"perform search", 								"search-2a996591375a",
		" ESCAPE", 		"dismisss search bar", 							"search-2a996591375a",
		"",				"", "",
		"uKEY + COMMAND",		"", "",
		" A", 			"select all search text", 						"search-2a996591375a",
		" F", 			"dismisss search bar", 							"search-2a996591375a",
		"",				"", "",
	]

	let graphColumnTwo: [String] = [
		"",				"", "",
		"bWHILE EDITING AN IDEA:", "", "",
		"",				"", "",
		"uKEY",			"", "",
		" ESCAPE", 		"cancel edit, discarding changes", 				"edit-d05d18996df7",
		"",				"", "",
		"uKEY + COMMAND",		"", "",
		" PERIOD", 		"cancel edit, discarding changes", 				"edit-d05d18996df7",
		" A", 			"select all text", 								"edit-d05d18996df7",
		"pI", 			"show special characters popup menu", 			"",
		"p",			"", "",
		"UKEY + COMMAND + OPTION", "", "",
		"pPERIOD", 		"toggle lists grow up/down,",					"",
		"p", 			"(and) move idea up/down", 						"organize-fcdc44ac04e4",
		"p",			"", "",
		"uKEY + OPTION",      "", "",
		" SPACE", 		"create child idea", 							"edit-d05d18996df7",
		"",				"", "",
		"",				"", "",
		"bWHILE EDITING (TEXT IS SELECTED):",	"", "",
		"",				"", "",
		"psurround:", 	"| [ { ( < \" ' SPACE",							"edit-d05d18996df7",
		"p",			"", "",
		"uKEY + COMMAND",		"", "",
		"pD", 			"if all selected, append onto parent", 			"parent-child-tweaks-bf067abdf461",
		"p ", 			"if not all selected, create as a child", 		"parent-child-tweaks-bf067abdf461",
		" L", 			"-> lowercase", 								"edit-d05d18996df7",
		" U", 			"-> uppercase", 								"edit-d05d18996df7",
		"",				"", "",
		"",				"", "",
		"i",			"", "",
		"bWHILE IN THE SEARCH RESULTS:",	"", "",
		"",				"", "",
		"uKEY",			"", "",
		" RETURN", 		"focus on selected result", 					"search-2a996591375a",
		"",				"", "",
		"uARROW KEY",	"", "",
		" LEFT", 		"exit search", 									"search-2a996591375a",
		" RIGHT", 		"focus on selected result", 					"search-2a996591375a",
		" vertical", 	"browse results (wraps around)", 				"search-2a996591375a",
		"",				"", "",
	]

	let graphColumnThree: [String] = [
		"",				"", "",
		"bWHILE NAVIGATING (NOT EDITING AN IDEA):", "", "",
		"",				"", "",
		"pmark:", 		"" + kMarkingCharacters, 						"extras-2a9b1a7db21f",
		"p",			"", "",
		"uKEY",			"", "",
		" ARROWS", 		"navigate map", 								"",
		"pCOMMA", 		"toggle navigation: un/confined", 				"",
		" DELETE", 		"selected ideas and their progeny", 			"organize-fcdc44ac04e4",
		"pHYPHEN", 		"add 'line', or un/title it", 					"lines-37426469b7c6",
		"pPERIOD", 		"toggle lists grow up/down", 					"",
		" SPACE", 		"create an idea", 								"edit-d05d18996df7",
		" /", 			"focus (also, manage favorite)", 				"focusing-your-thinking-a53adb16bba",
		" \\", 			"switch to other map", 				    		"",
		"p'", 			"switch between recents & favorites",			"focusing-your-thinking-a53adb16bba",
		" [", 			"-> prior idea", 								"focusing-your-thinking-a53adb16bba",
		" ]", 			"-> next idea",         						"focusing-your-thinking-a53adb16bba",
		"p=", 			"invoke hyperlink or email", 					"extras-2a9b1a7db21f",
		"pB", 			"create a bookmark", 							"focusing-your-thinking-a53adb16bba",
		" C", 			"recenter the map", 							"",
		" D", 			"duplicate", 									"",
		"pE", 			"create or edit hidden email address",			"extras-2a9b1a7db21f",
		" F", 			"search", 										"search-2a996591375a",
		"pG", 			"refetch children of selection", 				"cloud-vs-file-f3543f7281ac",
		"pH", 			"create or edit hidden hyperlink", 				"extras-2a9b1a7db21f",
		"pK", 			"un/color the text", 							"extras-2a9b1a7db21f",
		" L", 			"-> lowercase", 								"edit-d05d18996df7",
		" N",			"create or edit hidden note",					"",
		"pO", 			"import from a Seriously file", 				"cloud-vs-file-f3543f7281ac",
		" R", 			"reverse order of children", 					"organize-fcdc44ac04e4",
		"pS", 			"save to a Seriously file", 					"cloud-vs-file-f3543f7281ac",
		"pT", 			"swap selected idea with parent", 				"parent-child-tweaks-bf067abdf461",
		" U", 			"-> uppercase", 								"edit-d05d18996df7",
		"",				"", "",
		"uKEY + COMMAND + OPTION", "", "",
		" DELETE", 		"permanently (not into trash)", 				"organize-fcdc44ac04e4",
		"pHYPHEN", 		"-> titled line to/from parent",			 	"lines-37426469b7c6",
		"pO", 			"show data files in Finder", 					"cloud-vs-file-f3543f7281ac",
		" S", 			"save to cloud",			 					"cloud-vs-file-f3543f7281ac",
		"",				"", "",
		"p",            "PALE BLUE BACKGROUND INDICATES PRO FEATURE", "",
	]

	let graphColumnFour: [String] = [
		"",				"", "",
		"",				"", "",
		"uKEY + OPTION",		"", "",
		" ARROWS", 		"move selected idea", 							"organize-fcdc44ac04e4",
		"pDELETE", 		"retaining children", 							"organize-fcdc44ac04e4",
		"pRETURN", 		"edit with cursor at end", 						"edit-d05d18996df7",
		"pHYPHEN", 		"convert text to or from 'titled line'", 		"lines-37426469b7c6",
		" TAB", 		"new idea containing", 							"edit-d05d18996df7",
		"pG", 			"refetch entire submap of selection", 	 		"cloud-vs-file-f3543f7281ac",
		"pS", 			"export to a outline file", 					"cloud-vs-file-f3543f7281ac",
		"",				"", "",
		"uKEY + COMMAND",		"", "",
		"pARROWS", 		"extend all the way", 							"selecting-ideas-cc2939720e53",
		" HYPHEN", 		"reduce font size", 							"",
		" +", 		    "increase font size", 							"",
		" /", 			"refocus current favorite", 					"focusing-your-thinking-a53adb16bba",
		" A", 			"select all ideas", 							"selecting-ideas-cc2939720e53",
		"pD", 			"append onto parent", 							"parent-child-tweaks-bf067abdf461",
		"pG", 			"refetch entire map",   						"cloud-vs-file-f3543f7281ac",
		"",				"", "",
		"uKEY + MOUSE CLICK",	"", "",
		" COMMAND", 	"move entire map", 							    "mouse-e21b7a63020e",
		" SHIFT", 		"un/extend selection", 							"selecting-ideas-cc2939720e53",
		"",				"", "",
		"uARROW KEY + SHIFT (+ COMMAND -> all)", "", "",
		" LEFT ", 		"hide children", 								"focusing-your-thinking-a53adb16bba",
		" RIGHT", 		"reveal children", 								"focusing-your-thinking-a53adb16bba",
		" vertical", 	"extend selection", 							"selecting-ideas-cc2939720e53",
		"",				"", "",
		"",				"", "",
		"BNAVIGATING (MULTIPLE IDEAS SELECTED):",	"", "",
		"p",			"", "",
		"UKEY",			"", "",
		"pHYPHEN", 		"if first selected idea is titled, -> parent", 	"lines-37426469b7c6",
		"p#", 			"mark with ascending numbers", 					"extras-2a9b1a7db21f",
		"pA", 			"alphabetize (+ OPTION -> backwards)", 			"organize-fcdc44ac04e4",
		"pM", 			"sort by length (+ OPTION -> backwards)", 		"organize-fcdc44ac04e4",
		"pR", 			"reverse order", 								"organize-fcdc44ac04e4",
		"",				"", "",
	]
}