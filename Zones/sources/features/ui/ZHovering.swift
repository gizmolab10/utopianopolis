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

	var dot             : ZoneDot?
	var widget          : ZoneWidget?
	var textWidget      : ZoneTextWidget?

	var absoluteView    : ZView? {
		if  textWidget != nil || widget != nil || dot != nil {
			return gMapView
		}

		return nil
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

		var hover       = false
		p   .isHovering = true
		if  let       d = p as? ZoneDot {
			hover       = true
			dot         = d
		} else if let w = p as? ZoneWidget {
			hover       = true
			widget      = w
		}

		return hover ? gMapView : nil
	}

	func setHover(on t: ZoneTextWidget) -> ZView? {
		clear()

		t.isHovering = true
		textWidget   = t

		return gMapView
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
