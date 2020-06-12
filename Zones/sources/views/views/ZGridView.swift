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
						let o = dirtyRect.origin
						let y = Double(row)    *  17.0 + Double(o.y)
						let x = Double(column) * 580.0 + Double(o.x) + 20.0
						let p = CGPoint(x: x, y: y)
						let s = CGSize(width: gDotWidth, height: gDotHeight)
						let r = CGRect(origin: p, size: s)
						let d = ZoneDot()

//						d.drawInnerDot(r)
						print("\(row) \(column) \(command)")
					}
				}
			}
		}
	}

}
