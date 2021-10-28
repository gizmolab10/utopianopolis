//
//  ZHovering.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/26/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

let gHovering = ZHovering()

class ZHovering: NSObject {

	var dot        : ZoneDot?
	var textWidget : ZoneTextWidget?

	func clear() {
		dot?                 .isHovering = false
		textWidget?          .isHovering = false
		dot                              = nil
		textWidget                       = nil
	}

	func declareHover(_ iDot: ZoneDot?) {
		clear()

		if  let           d = iDot {
			dot             = d
			dot?.isHovering = true
		}
	}

	func declareHover(_ iTextWidget: ZoneTextWidget?) {
		clear()

		if  let                  t = iTextWidget {
			textWidget             = t
			textWidget?.isHovering = true
		}
	}

}
