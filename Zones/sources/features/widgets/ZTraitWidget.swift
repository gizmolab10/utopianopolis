//
//  ZTraitWidget.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/25/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

class ZTraitWidget : ZPseudoView {

	var string : String?
	var dot    : ZoneDot?
	var angle  : CGFloat = .zero

	var font: ZFont? {
		if  let c = controller ?? gHelpController {
			let w = c.dotWidth * 0.9

			return ZFont.systemFont(ofSize: w)
		}

		return nil
	}

	init(view: ZView?, with trait: String, at angle: CGFloat, around dot: ZoneDot) {
		super.init(view: view)

		self.string = trait
		self.angle  = angle
		self.dot    = dot
	}

	@discardableResult func updateTraitWidgetDrawnSize() -> CGSize {
		if  let     f = font,
			let     s = string {
			drawnSize = s.sizeWithFont(f)
		}

		return drawnSize
	}

	func draw(_ parameters: ZDotParameters) {
		if  let        c = controller ?? gHelpController,
			let        s = string,
			let        f = font,
			let        d = dot {
			let isFilled = parameters.isFilled
			let    color = isFilled ? gBackgroundColor : parameters.color
			let altColor = isFilled ? parameters.color : gBackgroundColor
			let   offset = drawnSize.dividedInHalf.multiplyBy(CGSize(width: 1.0, height: 0.7))
			let   center = absoluteCenter.offsetBy(.zero, (-offset.height / 2.5))
			let    other = CGRect(center: center, size: CGSize.squared(c.dotWidth))

			altColor.setFill()
			d.drawMainDot(other, ZDotParameters(isReveal: true, isCircle: true))
			s.draw(in: absoluteFrame, withAttributes: [.foregroundColor : color, .font: f])
		}
	}
}
