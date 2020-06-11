//
//  ZDotDecorations.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZDotDecorations: ZDocumentation {

	override var noTabPrefix       :   String   { return "               " }
	override var columnStrings     : [[String]] { return [dotsColumnOne, dotsColumnTwo] }
	override var tabOffsets        :  [Int]     { return [0, 20, 150] }
	override var columnWidth       :   Int      { return 580 }
	override var indexOfLastColumn :   Int      { return 1 }

	let dotsColumnOne: [String] = [
		"",		"","",
		"bLEFT SIDE DOTS","click to select or drag","",
		"",		"","",
		"n",	"plain","",
		"n",	"currently selected","",
		"n",	"current focus (only in favorites or recents)","",
		"n",	"read only",""
	]

	let dotsColumnTwo: [String] = [
		"","","",
		"bRIGHT SIDE DOTS","click to conceal, reveal or activate","",
		"","","",
		"Uhas hidden ideas","undecorated","",
		"","","",
		"n",	"one idea","",
		"n",	"five ideas","",
		"n",	"ten ideas","",
		"n",	"eleven ideas","",
		"","","",
		"uhas revealed ideas","undecorated","",
		"","","",
		"n",	"click to hide ideas","",
		"","","",
		"udecorated","","",
		"","","",
		"n",	"bookmark","",
		"n",	"email","",
		"n",	"hyperlink","",
		"n",	"note or essay",""
	]

}
