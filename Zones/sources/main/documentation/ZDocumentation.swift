//
//  ZDocumentation.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/9/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZDocumentation: NSObject {

	var tabStops          =   [NSTextTab]()
	var tabOffsets        :   [Int] { return [20, 85] } // default for graph shortcuts
	var columnWidth       :    Int  { return 290 }      // "
	var indexOfLastColumn :    Int  { return 3 }        // "
	var countPerRow       :    Int  { return 3 }
	var countOfRows       :    Int  { return 1 }
	var hyperlinkColor    :  ZColor { return gIsDark ? kBlueColor.lighter(by: 3.0) : kBlueColor.darker (by:  2.0) }
	var powerUserColor    :  ZColor { return gIsDark ? kBlueColor.darker (by: 5.0) : kBlueColor.lighter(by: 30.0) }

	func strings(for          row: Int, column: Int) -> (String, String, String)  { return ("", "", "") }
	func attributedString(for row: Int, column: Int) -> NSMutableAttributedString { return NSMutableAttributedString() }

	func setup() {
		var values: [Int] = []
		var offset = 0

		for _ in 0...indexOfLastColumn {
			values.append(offset)
			values.append(offset + tabOffsets[0])
			values.append(offset + tabOffsets[1])

			offset += columnWidth
		}

		for     value in values {
			if  value != 0 {
				tabStops.append(NSTextTab(textAlignment: .left, location: CGFloat(value), options: [:]))
			}
		}
	}

	func objectValueFor(_ row: Int) -> NSMutableAttributedString {
		let         result = NSMutableAttributedString()
		let      paragraph = NSMutableParagraphStyle()
		paragraph.tabStops = tabStops

		for column in 0...indexOfLastColumn {
			let a = attributedString(for: row, column: column)

			result.append(a)
		}

		result.addAttribute(.paragraphStyle, value: paragraph as Any, range: NSMakeRange(0, result.length))

		return result
	}

	func url(for row: Int, column: Int) -> String? {
		let m = "https://medium.com/@sand_74696/"
		let (_, _, url) = strings(for: row, column: column)

		return url.isEmpty ? nil : m + url
	}

}
