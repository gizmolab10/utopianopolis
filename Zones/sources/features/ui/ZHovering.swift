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
	var widget       : ZoneWidget?
	var textWidget   : ZoneTextWidget?

	var absoluteView : ZView? {
		if  let    t = textWidget?.widget?.absoluteView as? ZMapView {
			return t
		} else if let m = dot?.absoluteView as? ZMapView {
			return    m.dotsAndLinesView
		} else if let w = widget?.absoluteView as? ZMapView {
			return    w
		}

		return nil
	}

	@discardableResult func clear() -> ZView? {
		let            cleared = absoluteView
		dot?       .isHovering = false
		widget?    .isHovering = false
		textWidget?.isHovering = false
		dot                    = nil
		widget                 = nil
		textWidget             = nil

		return cleared
	}
	
	func setHover(on pseudoView: ZPseudoView) {
		clear()

		if  let       d = pseudoView as? ZoneDot {
			dot         = d
		} else if let w = pseudoView as? ZoneWidget {
			widget      = w
		}
	}

	func declareHover(_ iTextWidget: ZoneTextWidget?) -> Bool {
		clear()
		
		if  let        t = iTextWidget {
			textWidget   = t
			t.isHovering = true
		}

		return true
	}

	func declareHover(_ view: ZPseudoView) -> Bool {
		setHover(on: view)

		view.isHovering = true

		return true
	}

}

extension ZoneWidget {

	func detectHover(at location: CGPoint) -> Bool {
		if  let           z = widgetZone, z.isShowing {
			for line in childrenLines {
				if  let   r = line.revealDot,      r.detectionFrame.contains(location) {
					return gHovering.declareHover(r)
				}
			}
			if  let       d = parentLine?.dragDot, d.detectionFrame.contains(location) {
				return gHovering.declareHover(d)
			} else if let t = pseudoTextWidget,    t.detectionFrame.contains(location) {
				return gHovering.declareHover(textWidget)
			} else if isCircularMode,                detectionFrame.contains(location) {
				return gHovering.declareHover(self)
			}
		}

		return false
	}

}

extension ZMapController {

	@discardableResult func detectHover(at locationInWindow: CGPoint?) -> ZView? {
		if  let              w = locationInWindow,
			let       location = gMapView?.convert(w, from: gMapView?.window?.contentView) {
			if  let     widget = detectWidget(at: location),
				widget.detectHover(at: location) {
				return gMapView
			} else if gHovering.clear() != nil {
				return gMapView
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
