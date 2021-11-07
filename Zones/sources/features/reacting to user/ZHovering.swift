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

	var dot          : ZoneDot?
	var textWidget   : ZoneTextWidget?

	var absoluteView : ZView? {
		if  let    t = textWidget?.widget?.absoluteView as? ZMapView {
			return t
		} else if let m = dot?.absoluteView as? ZMapView {
			return    m.dotsAndLinesView
		}

		return nil
	}

	@discardableResult func clear() -> ZView? {
		let            cleared = absoluteView
		dot?       .isHovering = false
		textWidget?.isHovering = false
		dot                    = nil
		textWidget             = nil

		return cleared
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

extension ZoneWidget {

	func detectHover(at location: CGPoint) -> Bool {
		if  let       d = dragDot,   d.absoluteFrame.contains(location) {
			gHovering.declareHover(d)
		} else if let r = revealDot, r.absoluteFrame.contains(location) {
			gHovering.declareHover(r)
		} else if let t = pseudoTextWidget, t.absoluteFrame.contains(location) {
			gHovering.declareHover(t.actualTextWidget)
		} else {
			return false
		}

		return true
	}

}

extension ZMapController {

	@discardableResult func detectHover(at locationInWindow: CGPoint?) -> ZView? {
		if  let              w = locationInWindow,
			let       location = mapView?.convert(w, from: mapView?.window?.contentView) {
			if  let     widget = detectWidget(at: location),
				widget.detectHover(at: location) {
				return   mapView
			} else if gHovering.clear() != nil {
				return   mapView
			}
		}

		return nil
	}

}

extension ZDragView {

	override func mouseMoved(with event: ZEvent) {
		super.mouseMoved(with: event)
		gMapController?.detectHover(at: event.locationInWindow)?.setNeedsDisplay()
	}

}
