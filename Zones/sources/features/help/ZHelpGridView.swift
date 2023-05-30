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
					let vo = Double(data.rowHeight) + data.dotOffset
					let  x = Double(column) * 580.0 + Double(iDirtyRect.minX)   + 30.0
					let  y = Double(row)    *   -vo + Double(iDirtyRect.height) - 24.0
					let  d = ZoneDot(view: self)

					func internalDraw(_ isFavorite: Bool = false, xOffset : Double = .zero, _ parameters: ZDotParameters) {
						let point = CGPoint(x: x + xOffset, y: y)
						let  rect = dt.rect(point)
						let types = parameters.traitTypes

						if  types.count > 1 {
							d.absoluteFrame = rect

							d.setupForTraits(types)
							d.linearUpdateDotAbsoluteFrame(relativeTo: rect.center)   // TODO: dot's controller is nil
						}

						d.drawDot(rect, parameters)

						if  isFavorite {
							parameters.color.withAlphaComponent(0.7).setFill()
						}

						d.drawDotExterior(rect, parameters)
					}

					if  ft != .fFilled {
						internalDraw(dt == .favorite, dt.helpDotParameters())                                    // draw empty dot in first column
					}

					if  ft != .fEmpty {
						internalDraw(xOffset: 45.0, dt.helpDotParameters(isFilled: true))                        // draw filled dot in second column
					}

					if  ft == .fThree {
						internalDraw(xOffset: 90.0, dt.helpDotParameters(isFilled: true, showAsACircle: true))   // draw filled circle in third column
					}
				}
			}
		}
	}
}
