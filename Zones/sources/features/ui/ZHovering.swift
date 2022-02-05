//
//  ZHovering.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/26/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

let gHovering = ZHovering()
var gIgnoreHovering : Bool { return gRubberband.showRubberband || gDragging.isDragging }
func gUpdateHover() { gMapController?.detectHover() }

class ZHovering: NSObject {

	var dot             : ZoneDot?
	var widget          : ZoneWidget?
	var textWidget      : ZoneTextWidget?
	var onObject        : AnyObject? { return dot ?? widget ?? textWidget }
	var showHover       : Bool       { return absoluteView != nil }

	var absoluteView    : ZView? {
		if  dot != nil {
			return gLinesAndDotsView
		} else if textWidget != nil || widget != nil {
			return gMapView
		}

		return nil
	}

	func onObject(at location: CGPoint) -> AnyObject? {
		if  let object = onObject {
			if  let pseudo = object as? ZPseudoView {
				if  pseudo.absoluteFrame.contains(location) {
					return pseudo
				}
			} else if let t = object as? ZoneTextWidget,
					  let p = t.widget?.pseudoTextWidget,
					  p.absoluteFrame.contains(location) {
				return t
			}
		}

		return nil
	}

	@discardableResult func clear() -> Bool {
		let            cleared = showHover // do this before setting everything to nil
		dot?       .isHovering = false
		widget?    .isHovering = false
		textWidget?.isHovering = false
		dot                    = nil
		widget                 = nil
		textWidget             = nil

		return cleared
	}

	func setHover(on p: ZPseudoView) {
		clear()

		if  let       d = p as? ZoneDot {
			dot         = d
		} else if let w = p as? ZoneWidget {
			widget      = w
		} else {
			return
		}

		p   .isHovering = true
	}

	func setHover(on t: ZoneTextWidget) {
		clear()

		t.isHovering = true
		textWidget   = t
	}
	
	@discardableResult func declareHover(_ any: Any?) -> Bool {
		if  let p = any as? ZPseudoView {
			setHover(on: p)
		}

		if  let t = any as? ZoneTextWidget {
			setHover(on: t)
		}
		
		return showHover
	}

}

extension ZMapController {

	func detectHover() {
		if  let point = gMapView?.currentMouseLocation, detectHover(at: point) {
			setNeedsDisplay()
		}
	}

	@discardableResult func detectHover(at locationInWindow: CGPoint?) -> Bool {
		if  let location = locationInWindow, !gIgnoreHovering { // not blink rubberband
			if  let  any = detectHit(at: location) {
				return gHovering.declareHover(any)
			} else {
				return gHovering.clear()
			}
		}

		return false
	}

}
