//
//  ZHelpNotesData.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZHelpEssayData: ZHelpData {

	override var noTabPrefix       :   String   { return "                    " }
	override var columnStrings     : [[String]] { return [essayColumnOne, essayColumnTwo] }
	override var tabOffsets        :  [Int]     { return [0, 20, 150] }
	override var columnWidth       :   Int      { return 580 }
	override var indexOfLastColumn :   Int      { return 1 }
	override var rowHeight         :   CGFloat  { return 22.0 }
	override var boldFont          :   ZFont    { return kLargeBoldFont }

	let essayColumnOne: [String] = prefixArray + [
		"",						"",																				"",
		"_drag dot",			"filled dots indicate idea is selected",										""
	]

	let essayColumnTwo: [String] = prefixArray + [
		"",						"",																				"",
		"_no dot indicates no list and nothing to activate",												"", ""
	]

}
