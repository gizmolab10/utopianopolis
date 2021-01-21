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

	override func draw(_ dirtyRect: NSRect) {
		super.draw(dirtyRect)

		if  !isHidden,
			let      data  = helpData,
			data.helpMode == .dotMode {
			drawDotsHelp(in: dirtyRect, using: data)
		}
	}

	func drawDotsHelp(in dirtyRect: NSRect, using data: ZHelpData) {
		for row        in  0..<data.countOfRows {
			for column in  0...data.indexOfLastColumn {
				let (dc, ft) = data.dotTypes(for: row, column: column)
				if  let c = dc,
					let t = ft {
					var e = true
					var f = true
					let v = Double(data.rowHeight) + 2.0
					let y = Double(row)    *    -v + Double(dirtyRect.extent.y) - 24.0
					let x = Double(column) * 580.0 + Double(dirtyRect.origin.x) + 30.0
					let d = ZoneDot()

					switch t {
						case .filled: e = false
						case .empty:  f = false
						default:      break
					}

					if  e {
						// draw empty in first column

						let p = CGPoint(x: x, y: y)
						let r = c.rect(p)
						let m = c.dotParameters()

						d.drawInnerDot(r, m)

						if  c == .favorite {
							m.color.withAlphaComponent(0.7).setFill()
							d.drawOuterDot(r, m)
						}
					}

					if  f {
						// draw filled in second column

						let p = CGPoint(x: x + 20.0, y: y)
						let r = c.rect(p)
						let m = c.dotParameters(isFilled: true)

						d.drawInnerDot(r, m)
						d.drawOuterDot(r, m)
					}
				}
			}
		}
	}
}
