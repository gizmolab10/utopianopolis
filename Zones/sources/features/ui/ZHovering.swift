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

	var dot           : ZoneDot?
	var widget        : ZoneWidget?
	var textWidget    : ZoneTextWidget?

	var absoluteView  : ZView? {
		if  let       t = textWidget?.widget?.absoluteView as? ZMapView {
			return    t
		} else if let m = dot?               .absoluteView as? ZMapView {
			return    m.dotsAndLinesView
		} else if let w = widget?            .absoluteView as? ZMapView {
			return    w
		}

		return nil  // too often returns nil
	}

	@discardableResult func clear() -> ZView? {
		let            cleared = absoluteView // do this before setting to nil (below)
		dot?       .isHovering = false
		widget?    .isHovering = false
		textWidget?.isHovering = false
		dot                    = nil
		widget                 = nil
		textWidget             = nil

		return cleared
	}
	
	func setHover(on p: ZPseudoView) -> ZView? {
		clear()

		p   .isHovering = true
		if  let       d = p as? ZoneDot {
			dot         = d
		} else if let w = p as? ZoneWidget {
			widget      = w
		}

		return p.absoluteView
	}

	func setHover(on t: ZoneTextWidget) -> ZView? {
		clear()

		t.isHovering = true
		textWidget   = t

		return t.widget?.absoluteView
	}
	
	@discardableResult func declareHover(_ any: Any?) -> ZView? {
		if  let p = any as? ZPseudoView {
			return setHover(on: p)
		}

		if  let t = any as? ZoneTextWidget {
			return setHover(on: t)
		}
		
		return nil
	}

}

extension ZMapController {

	@discardableResult func detectHover(at locationInWindow: CGPoint?) -> ZView? {
		if  let     location = locationInWindow {
			if  let      any = detect(at: location) {
				if  let    v = gHovering.declareHover(any) {
					return v
				}
			} else if let  v = gHovering.clear() {
				return     v
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
