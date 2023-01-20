//
//  ZHelpGridView.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/11/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZHelpGridView: ZView {

	var helpData: ZHelpData?

	override func draw(_ iDirtyRect: NSRect) {
		super.draw(iDirtyRect)

		if  let data = helpData, !isHidden,
			data.helpMode.showsDots {
			gBaseFontSize = ZFont.systemFontSize * 0.7
			drawDotsHelp(in: iDirtyRect, using: data)
		}
	}

	func drawDotsHelp(in iDirtyRect: NSRect, using data: ZHelpData) {
		for row        in  0..<data.countOfRows {
			for column in  0...data.indexOfLastColumn {
				let (dc, ft) = data.dotTypes(for: row, column: column)
				if  let c = dc,
					let t = ft {
					let f = t != .empty
					let e = t != .filled
					let v = Double(data.rowHeight) + data.dotOffset
					let x = Double(column) * 580.0 + Double(iDirtyRect.minX)   + 30.0
					let y = Double(row)    *    -v + Double(iDirtyRect.height) - 24.0
					let d = ZoneDot(view: self)

					if  e {
						// draw e in first column

						let p = CGPoint(x: x, y: y)
						let r = c.rect(p)
						let m = c.helpDotParameters()

						d.drawDot(r, m)

						if  c == .favorite {
							m.color.withAlphaComponent(0.7).setFill()
							d.drawAroundDot(r, m)
						}
					}

					if  f {
						// draw f in second column

						let p = CGPoint(x: x + 20.0, y: y)
						let r = c.rect(p)
						let m = c.helpDotParameters(isFilled: true)

						d.drawDot(r, m)
						d.drawAroundDot(r, m)
					}
				}
			}
		}
	}
}
