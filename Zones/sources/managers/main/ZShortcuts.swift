//
//  ZShortcuts.swift
//  Zones
//
//  Created by Jonathan Sand on 1/4/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZShortcuts : NSObject {

	var numberOfRows: Int { return max(graphColumnOne.count, max(graphColumnTwo.count, max(graphColumnThree.count, graphColumnFour.count))) / 3 }
	var tabStops = [NSTextTab]()
	let bold = ZFont.boldSystemFont(ofSize: ZFont.systemFontSize)
	let columnWidth = 290

	func setup() {
		var values: [Int] = []
		var offset = 0

		for _ in 0...3 {
			values.append(offset)
			values.append(offset + 20)
			values.append(offset + 85)

			offset += columnWidth
		}

		for value in values {
			if value != 0 {
				tabStops.append(NSTextTab(textAlignment: .left, location: CGFloat(value), options: [:]))
			}
		}
	}

	func strings(for row: Int, column: Int) -> (String, String, String) {
		let columnStrings = [graphColumnOne, graphColumnTwo, graphColumnThree, graphColumnFour]
		let       strings = columnStrings[column]
		let 		index = row * 3

		return index >= strings.count ? ("", "", "") : (strings[index], strings[index + 1], strings[index + 2])
	}


	func url(for row: Int, column: Int) -> String? {
		let m = "https://medium.com/@sand_74696/"
		let (_, _, url) = strings(for: row, column: column)

		return url.isEmpty ? nil : m + url
	}


	func attributedString(for row: Int, column: Int) -> NSMutableAttributedString {
		var (m, e, url) = strings(for: row, column: column)
		let        type = ZShortcutType(rawValue: m.substring(with: NSMakeRange(0, 1))) // grab first character
		let        main = m.substring(fromInclusive: 1)             // grab remaining characters
		var  attributes = ZAttributesDictionary ()
		let      hasURL = !url.isEmpty
		var      prefix = "   "

		switch type {
			case .bold?:
				attributes  = [.font : bold]
			case .append?, .underline?:
				attributes  = [.underlineStyle : 1]

				if type == .append {
					prefix += "+ "
				}

			case .plain?:
				if  hasURL {
					attributes = [.foregroundColor : ZColor.blue.darker(by: 5.0)]
					e.append(kEllipsis)
				}

				fallthrough

			default:
				prefix  = kTab		// for empty lines, including after last row
		}

		let result  = NSMutableAttributedString(string: prefix)

		if  type == .plain {
			result.append(NSAttributedString(string: main))
		} else {
			result.append(NSAttributedString(string: main, attributes: attributes))
		}

		if  e.length > 3 {
			result.append(NSAttributedString(string: kTab))
			result.append(NSAttributedString(string: e, attributes: attributes))
		}

		if  main.length + e.length < 11 && row != 1 && type != .plain {
			result.append(NSAttributedString(string: kTab)) 	// KLUDGE to fix bug in first column where underlined "KEY" doesn't have enough subsequent tabs
		}

		result.append(NSAttributedString(string: kTab))

		return result
	}


	let graphColumnOne: [String] = [
		"",				"", "",
		"bALWAYS:\t",	"", "",
		"",				"", "",
		"uKEY", 		"", "",
		" RETURN", 		"begin or end editing idea", 					"edit-d05d18996df7",
		" SPACE", 		"create subordinate idea", 						"edit-d05d18996df7",
		" TAB", 		"create next idea", 							"edit-d05d18996df7",
		"",				"", "",
		"+COMMAND",		"", "",
		" RETURN", 		"begin or end editing hidden note", 			"",
		" COMMA", 		"show or hide preferences", 					"help-inspector-view-c360241147f2",
		" A", 			"select all",	 								"",
		" P", 			"print the graph (or this window)", 			"",
		" Y",			"toggle extent of breadcrumb list",				"",
		"",				"", "",
		"+CONTROL",		"", "",
		" COMMA", 		"toggle browsing: un/confined", 				"",
		" DELETE", 		"show trash", 									"organize-fcdc44ac04e4",
		" PERIOD", 		"toggle lists grow up/down",		 			"",
		" SPACE", 		"create an idea", 								"edit-d05d18996df7",
		" /", 			"remove current focus from the ring", 			"focusing-your-thinking-a53adb16bba",
		"",				"", "",
		"+COMMAND + OPTION", "", "",
		" RETURN", 		"begin editing hidden note",					"",
		" /", 			"show or hide this window", 					"",
		" A", 			"show About Seriously", 						"",
		" R", 			"report a problem", 							"",
		" X",			"clear the ring",								"",
		" Y",			"show or hide necklace tooltips",				"",
		"",				"", "",
		"",				"", "",
		"bSEARCH BAR:", "", "",
		"",				"", "",
		"uKEY",			"", "",
		" RETURN", 		"perform search", 								"search-2a996591375a",
		" ESCAPE", 		"dismisss search bar", 							"search-2a996591375a",
		"",				"", "",
		"+COMMAND",		"", "",
		" A", 			"select all search text", 						"search-2a996591375a",
		" F", 			"dismisss search bar", 							"search-2a996591375a",
		"",				"", "",
	]

	let graphColumnTwo: [String] = [
		"",				"", "",
		"bEDITING AN IDEA:", "", "",
		"",				"", "",
		"uKEY",			"", "",
		" ESCAPE", 		"cancel edit, discarding changes", 				"edit-d05d18996df7",
		"",				"", "",
		"+COMMAND",		"", "",
		" PERIOD", 		"cancel edit, discarding changes", 				"edit-d05d18996df7",
		" A", 			"select all text", 								"edit-d05d18996df7",
		" I", 			"show special characters popup menu", 			"",
		"",				"", "",
		"+COMMAND + OPTION", "", "",
		" PERIOD", 		"toggle lists grow up/down,",					"",
		"", 			"(and) move idea up/down", 						"organize-fcdc44ac04e4",
		"",				"", "",
		"+OPTION", "", "",
		" SPACE", 		"create subordinate idea", 						"edit-d05d18996df7",
		"",				"", "",
		"",				"", "",
		"",				"", "",
		"bEDITING (TEXT IS SELECTED):",	"", "",
		"",				"", "",
		" surround:", 	"| [ { ( < \" ' SPACE",							"edit-d05d18996df7",
		"",				"", "",
		"+COMMAND",		"", "",
		" D", 			"if all selected, append onto parent", 			"parent-child-tweaks-bf067abdf461",
		"  ", 			"if not all selected, create as a child", 		"parent-child-tweaks-bf067abdf461",
		" L", 			"-> lowercase", 								"edit-d05d18996df7",
		" U", 			"-> uppercase", 								"edit-d05d18996df7",
		"",				"", "",
		"",				"", "",
		"bSEARCH RESULTS:",	"", "",
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
		"bBROWSING (NOT EDITING AN IDEA):", "", "",
		"",				"", "",
		" mark:", 		"" + kMarkingCharacters, 						"extras-2a9b1a7db21f",
		"",				"", "",
		"uKEY",			"", "",
		" ARROWS", 		"navigate graph", 								"",
		" COMMA", 		"toggle browsing: un/confined", 				"",
		" DELETE", 		"selected ideas and their progeny", 			"organize-fcdc44ac04e4",
		" HYPHEN", 		"add 'line', or un/title it", 					"lines-37426469b7c6",
		" PERIOD", 		"toggle lists grow up/down", 					"",
		" SPACE", 		"create an idea", 								"edit-d05d18996df7",
		" /", 			"focus (also, manage favorite)", 				"focusing-your-thinking-a53adb16bba",
		" \\", 			"switch to other graph", 						"",
		" ;", 			"-> prior favorite", 							"focusing-your-thinking-a53adb16bba",
		" '", 			"-> next favorite", 							"focusing-your-thinking-a53adb16bba",
		" [", 			"-> prior in focus ring", 						"focusing-your-thinking-a53adb16bba",
		" ]", 			"-> next in focus ring", 						"focusing-your-thinking-a53adb16bba",
		" =", 			"invoke hyperlink or email", 					"extras-2a9b1a7db21f",
		" B", 			"create a bookmark", 							"focusing-your-thinking-a53adb16bba",
		" C", 			"recenter the graph", 							"",
		" D", 			"duplicate", 									"",
		" E", 			"create or edit hidden email address",			"extras-2a9b1a7db21f",
		" F", 			"search", 										"search-2a996591375a",
		" G", 			"refetch children of selection", 				"cloud-vs-file-f3543f7281ac",
		" H", 			"create or edit hidden hyperlink", 				"extras-2a9b1a7db21f",
		" J", 			"show or hide jump controls",					"",
		" K", 			"un/color the text", 							"extras-2a9b1a7db21f",
		" L", 			"-> lowercase", 								"edit-d05d18996df7",
		" N",			"create or edit hidden note",					"",
		" O", 			"import from a Seriously file", 				"cloud-vs-file-f3543f7281ac",
		" R", 			"reverse order of children", 					"organize-fcdc44ac04e4",
		" S", 			"save to a Seriously file", 					"cloud-vs-file-f3543f7281ac",
		" T", 			"swap selected idea with parent", 				"parent-child-tweaks-bf067abdf461",
		" U", 			"-> uppercase", 								"edit-d05d18996df7",
		"",				"", "",
		"+MOUSE CLICK",	"", "",
		" COMMAND", 	"move entire graph", 							"mouse-e21b7a63020e",
		" SHIFT", 		"un/extend selection", 							"selecting-ideas-cc2939720e53",
		"",				"", "",
	]

	let graphColumnFour: [String] = [
		"",				"", "",
		"+OPTION",		"", "",
		" ARROWS", 		"move selected idea", 							"organize-fcdc44ac04e4",
		" DELETE", 		"retaining children", 							"organize-fcdc44ac04e4",
		" RETURN", 		"edit with cursor at end", 						"edit-d05d18996df7",
		" HYPHEN", 		"convert text to or from 'titled line'", 		"lines-37426469b7c6",
		" TAB", 		"new idea containing", 							"edit-d05d18996df7",
		" G", 			"refetch entire subgraph of selection", 		"cloud-vs-file-f3543f7281ac",
		" S", 			"export to a outline file", 					"cloud-vs-file-f3543f7281ac",
		"",				"", "",
		"+COMMAND",		"", "",
		" ARROWS", 		"extend all the way", 							"selecting-ideas-cc2939720e53",
		" HYPHEN", 		"reduce font size", 							"",
		" +", 		    "increase font size", 							"",
		" /", 			"refocus current favorite", 					"focusing-your-thinking-a53adb16bba",
		" A", 			"select all ideas", 							"selecting-ideas-cc2939720e53",
		" D", 			"append onto parent", 							"parent-child-tweaks-bf067abdf461",
		" G", 			"refetch entire graph", 						"cloud-vs-file-f3543f7281ac",
		"",				"", "",
		"+COMMAND + OPTION", "", "",
		" DELETE", 		"permanently (not into trash)", 				"organize-fcdc44ac04e4",
		" HYPHEN", 		"-> titled line to/from parent",			 	"lines-37426469b7c6",
		" O", 			"show data files in Finder", 					"cloud-vs-file-f3543f7281ac",
		"",				"", "",
		"uARROW KEY + SHIFT (+ COMMAND -> all)", "", "",
		" LEFT ", 		"hide children", 								"focusing-your-thinking-a53adb16bba",
		" RIGHT", 		"reveal children", 								"focusing-your-thinking-a53adb16bba",
		" vertical", 	"extend selection", 							"selecting-ideas-cc2939720e53",
		"",				"", "",
		"",				"", "",
		"",				"", "",
		"bBROWSING (MULTIPLE IDEAS SELECTED):",	"", "",
		"",				"", "",
		"uKEY",			"", "",
		" HYPHEN", 		"if first selected idea is titled, -> parent", 	"lines-37426469b7c6",
		" #", 			"mark with ascending numbers", 					"extras-2a9b1a7db21f",
		" A", 			"alphabetize (+ OPTION -> backwards)", 			"organize-fcdc44ac04e4",
		" M", 			"sort by length (+ OPTION -> backwards)", 		"organize-fcdc44ac04e4",
		" R", 			"reverse order", 								"organize-fcdc44ac04e4",
		"",				"", "",
	]
}
