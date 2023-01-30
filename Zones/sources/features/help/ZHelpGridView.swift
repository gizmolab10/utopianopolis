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
				let (dotType, fillType) = data.dotTypes(for: row, column: column)
				if  let dt = dotType,
					let ft = fillType {
					let  f = ft != .fEmpty
					let  t = ft == .fThree
					let  e = ft != .fFilled
					let vo = Double(data.rowHeight) + data.dotOffset
					let  x = Double(column) * 580.0 + Double(iDirtyRect.minX)   + 30.0
					let  y = Double(row)    *    -vo + Double(iDirtyRect.height) - 24.0
					let  d = ZoneDot(view: self)

					if  e {
						// draw empty dot in first column

						let p = CGPoint(x: x, y: y)
						let r = dt.rect(p)
						let m = dt.helpDotParameters()

						d.drawDot(r, m)

						if  dt == .favorite {
							m.color.withAlphaComponent(0.7).setFill()
							d.drawDotExterior(r, m)
						}
					}

					if  f {
						// draw filled dot in second column

						let p = CGPoint(x: x + 20.0, y: y)
						let r = dt.rect(p)
						let m = dt.helpDotParameters(isFilled: true)

						d.drawDot(r, m)
						d.drawDotExterior(r, m)
					}

					if  t {
						// draw filled circle in third column

						let p = CGPoint(x: x + 40.0, y: y)
						let r = dt.rect(p)
						let m = dt.helpDotParameters(isFilled: true, isRound: true)

						d.drawDot(r, m)
						d.drawDotExterior(r, m)
					}
				}
			}
		}
	}
}
