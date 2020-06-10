//
//  ZDotDecorations.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZDotDecorations: ZDocumentation {

	override var tabOffsets        : [Int] { return [20, 490] }
	override var columnWidth       :  Int  { return 580 } // drag dots on left, reveal dots on right
	override var indexOfLastColumn :  Int  { return 1 }

	override func attributedString(for row: Int, column: Int) -> NSMutableAttributedString {
		let (_, b, _) = strings(for: row, column: column)

		return NSMutableAttributedString(string: kTab + b + kTab + kTab)
	}

	override func strings(for row: Int, column: Int) -> (String, String, String) {
		let columnStrings = [dotsColumnOne, dotsColumnTwo]

		return ("", columnStrings[column][row], "")
	}

	let dotsColumnOne: [String] = [
		"plain drag dot"
	]

	let dotsColumnTwo: [String] = [
		"plain reveal dot indicating hidden children"
	]

}
