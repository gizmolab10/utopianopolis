//
//  ZDotDecorations.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZDotDecorations: ZDocumentation {

	override var columnStrings     : [[String]] { return [dotsColumnOne, dotsColumnTwo] }
	override var tabOffsets        :  [Int]     { return [0, 20, 50] }
	override var columnWidth       :   Int      { return 580 } // drag dots on left, reveal dots on right
	override var indexOfLastColumn :   Int      { return 1 }

	let dotsColumnOne: [String] = [
		"","","",
		"bDRAG DOT","","",
		"","","",
		" ","plain, no decorations",""
	]

	let dotsColumnTwo: [String] = [
		"","","",
		"bREVEAL DOT","","",
		"","","",
		" ","plain, indicating hidden children",""
	]

}
