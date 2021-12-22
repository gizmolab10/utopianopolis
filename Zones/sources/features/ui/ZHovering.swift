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
	
	func declareHover(_ any: Any?) -> Bool {
		if  let p = any as? ZPseudoView {
			setHover(on: p)
			
			p.isHovering = true
			
			return true
		} else if let t = any as? ZoneTextWidget {
			clear()
			
			textWidget   = t
			t.isHovering = true

			return true
		}
		
		return false
	}

}

extension ZMapController {

	@discardableResult func detectHover(at locationInWindow: CGPoint?) -> ZView? {
		if  let location = locationInWindow {
			if  let  any = detect(at: location) {
				if  gHovering.declareHover(any) {
					return gMapView
				}
			} else if  gHovering.clear() != nil {
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
