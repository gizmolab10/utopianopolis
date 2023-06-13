//
//  ZTraitWidget.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/25/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

class ZTraitWidget : ZPseudoView {

	var angle : CGFloat = .zero
	var type  : String?
	var dot   : ZoneDot?

	init(view: ZView?, with type: String, at angle: CGFloat, around dot: ZoneDot) {
		super.init(view: view)

		self.angle = angle
		self.type  = type
		self.dot   = dot
	}

	func draw(_ parameters: ZDotParameters) {
		if  let        c = controller ?? gHelpController,
			let        t = type,
			let        f = font,
			let        d = dot {
			let isFilled = parameters.isFilled
			let    color = isFilled ? gBackgroundColor : parameters.color
			let altColor = isFilled ? parameters.color : gBackgroundColor
			let  vOffset = t == "#" ? -1.0 : 0.5
			let   offset = drawnSize.dividedInHalf.multiplyBy(CGSize(width: 1.0, height: 0.7)).offsetBy(.zero, vOffset)
			let   center = absoluteCenter.offsetBy(.zero, (-offset.height / 2.5))
			let    other = CGRect(center: center, size: CGSize.squared(c.dotWidth))

			altColor.setFill()
			d.drawMainDot(other, ZDotParameters(isReveal: true, isCircle: true))
			t.draw(in: absoluteFrame, withAttributes: [.foregroundColor : color, .font: f])

//			absoluteHitRect.drawColoredRect(.red)
		}
	}

	@discardableResult func updateTraitWidgetDrawnSize() -> CGSize {
		if  let     f = font,
			let     s = type {
			drawnSize = s.sizeWithFont(f)
		}

		return drawnSize
	}

	var font: ZFont? {
		if  let c = controller ?? gHelpController {
			let w = c.dotWidth * 0.9

			return ZFont.systemFont(ofSize: w)
		}

		return nil
	}

}
