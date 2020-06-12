//
//  ZGridView.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/11/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZGridView: ZView {

	var help: ZHelp?

	override func draw(_ dirtyRect: NSRect) {
		super.draw(dirtyRect)

		if  !isHidden,
			let h = help {
			for row        in  0..<h.countOfRows {
				for column in  0...h.indexOfLastColumn {
					let (dc, ft) = h.dotCommand(for: row, column: column)
					if  let c = dc,
						let t = ft {
						var e = false
						var f = true
						let o = dirtyRect.origin
						let y = Double(row)    *  17.0 + Double(o.y)
						let x = Double(column) * 580.0 + Double(o.x) + 20.0
						let s = CGSize(width: gDotWidth, height: gDotHeight)
						let d = ZoneDot()
						print("\(row) \(column) \(t) \(c)")

						switch t {
							case .both:  e = true
							case .empty: f = false
							default:     break
						}

						if  e {
							// draw empty in first column

							let p = CGPoint(x: x, y: y)
							let r = CGRect(origin: p, size: s)

							d.drawInnerDot(r, for: c)
						}

						if  f {
							// draw filled in second column

							let p = CGPoint(x: x + 30.0, y: y)
							let r = CGRect(origin: p, size: s)

							d.drawInnerDot(r, filled: true, tinyDotCount: c.count, for: c)
						}
					}
				}
			}
		}
	}

}
