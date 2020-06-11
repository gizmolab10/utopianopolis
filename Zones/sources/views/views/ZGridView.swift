//
//  ZGridView.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/11/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZGridView: ZView {

	var shortcuts: ZDocumentation?

	override func draw(_ dirtyRect: NSRect) {
		super.draw(dirtyRect)

		if  !isHidden,
			let s = shortcuts {
			for row in 0..<s.countOfRows {
				for column in 0...s.indexOfLastColumn {
					if  let command = s.dotCommand(for: row, column: column) {
						print("\(row) \(column) \(command)")
					}
				}
			}
		}
	}

}
