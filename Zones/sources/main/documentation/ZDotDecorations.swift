//
//  ZDotDecorations.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

enum ZDotCommand: String {
	case drag      = "plain"
	case selected  = "currently"
	case focus     = "current"
	case readOnly  = "read"
	case oneChild  = "one"
	case five      = "five"
	case ten       = "ten"
	case eleven    = "eleven"
	case click     = "click"
	case email     = "email"
	case bookmark  = "bookmark"
	case hyperlink = "hyperlink"
	case note      = "note"
}

class ZDotDecorations: ZDocumentation {

	override var noTabPrefix       :   String   { return "               " }
	override var columnStrings     : [[String]] { return [dotsColumnOne, dotsColumnTwo] }
	override var tabOffsets        :  [Int]     { return [0, 20, 150] }
	override var columnWidth       :   Int      { return 576 }
	override var indexOfLastColumn :   Int      { return 1 } // TODO: filled == third column

	override func dotCommand(for row: Int, column: Int) -> ZDotCommand? {
		let (first, second, _) = strings(for: row, column: column)
		let     rawChar  = first.substring(with: NSMakeRange(0, 1))
		let       lower  = rawChar.lowercased()
		let        type  = ZShortcutType(rawValue: lower)
		if         type == .dots {
			let    part  = second.components(separatedBy: " ")[0]

			return ZDotCommand(rawValue: part)
		}

		return nil
	}

	let dotsColumnOne: [String] = [
		"",		"","",
		"bLEFT SIDE DOTS","click to select or drag","",
		"",		"","",
		"d",	"plain","",
		"d",	"currently selected","",
		"d",	"current focus (only in favorites or recents)","",
		"d",	"read only",""
	]

	let dotsColumnTwo: [String] = [
		"","","",
		"bRIGHT SIDE DOTS","click to conceal, reveal or activate","",
		"","","",
		"Uhas hidden ideas","undecorated","",
		"","","",
		"d",	"one idea","",
		"d",	"five ideas","",
		"d",	"ten ideas","",
		"d",	"eleven ideas","",
		"","","",
		"uhas revealed ideas","undecorated","",
		"","","",
		"d",	"click to hide ideas","",
		"","","",
		"udecorated","","",
		"","","",
		"db",	"bookmark","",
		"de",	"email","",
		"dh",	"hyperlink","",
		"dn",	"note or essay",""
	]

}
