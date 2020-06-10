//
//  ZDocumentation.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/9/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZDocumentation: NSObject {

	var tabStops          = [NSTextTab]()
	var numberOfRows      : Int { return 1 }
	var indexOfLastColumn : Int { return 1 }
	var columnWidth       : Int { return 290 }

	func strings(for      row: Int, column: Int) -> (String, String, String)  { return ("", "", "") }
	func objectValueFor(_ row: Int)              -> NSMutableAttributedString { return NSMutableAttributedString() }

	func url(for row: Int, column: Int) -> String? {
		let m = "https://medium.com/@sand_74696/"
		let (_, _, url) = strings(for: row, column: column)

		return url.isEmpty ? nil : m + url
	}

}
