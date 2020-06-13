//
//  ZHelpGrid.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/11/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZHelpGrid: ZView {

	var help: ZHelp?

	func createParameters(from c: ZDotCommand, isFilled: Bool = false) -> ZoneDot.ZDotParameters {
		var p        = ZoneDot.ZDotParameters()
		p.fill       = isFilled ? p.color.lighter(by: 2.5) : gBackgroundColor
		p.filled     = isFilled
		p.isReveal   = c.isReveal
		p.traitType  = c.traitType
		p.pointRight = c.pointRight || !isFilled
		p.isBookmark = c == .bookmark
		p.childCount = c.count

		return p
	}

	override func draw(_ dirtyRect: NSRect) {
		super.draw(dirtyRect)

		if  !isHidden,
			let h = help {
			for row        in  0..<h.countOfRows {
				for column in  0...h.indexOfLastColumn {
					let (dc, ft) = h.dotCommand(for: row, column: column)
					if  let c = dc,
						let t = ft {
						var e = true
						var f = true
						let y = Double(row + 1) * -19.0 + Double(dirtyRect.extent.y) +  3.0
						let x = Double(column)  * 580.0 + Double(dirtyRect.origin.x) + 20.0
						let s = CGSize(width: gDotHeight, height: gDotHeight)
						let d = ZoneDot()
						d.innerDot = ZoneDot()
						print("\(row) \(column) \(t) \(c)")

						switch t {
							case .filled: e = false
							case .empty:  f = false
							default:      break
						}

						if  e {
							// draw empty in first column

							let p = CGPoint(x: x, y: y)
							let r = CGRect(origin: p, size: s)
							let m = createParameters(from: c)

							d.drawInnerDot(r, m)
						}

						if  f {
							// draw filled in second column

							let p = CGPoint(x: x + 20.0, y: y)
							let r = CGRect(origin: p, size: s)
							let m = createParameters(from: c, isFilled: true)

							d.drawInnerDot(r, m)
							d.drawOuterDot(r, m)
						}
					}
				}
			}
		}
	}

}
