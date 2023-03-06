//
//  ZHovering.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/26/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

class ZHovering: NSObject {

	var dot             : ZoneDot?
	var widget          : ZoneWidget?
	var textWidget      : ZoneTextWidget?
	var absoluteView    : ZView?     { return dot?.absoluteView ?? textWidget?.controller?.mapView ?? widget?.absoluteView }
	var onObject        : AnyObject? { return dot ?? widget ?? textWidget }
	var showHover       : Bool       { return absoluteView != nil }

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

		var isHovering  = true
		if  let       d = p as? ZoneDot {
			dot         = d
		} else if let w = p as? ZoneWidget {
			widget      = w
		} else {
			isHovering  = false
		}
		p.isHovering    = isHovering // isHovering affects draw (e.g., filled or dashed outline)
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

extension ZMapView {

	var shouldDetectHovering : Bool {
		return gIsReadyToShowUI
		&& !gDragging.isDragging
		&& !gRubberband.showRubberband    // not blink rubberband or drag
	}

	@discardableResult func detectHover() -> Bool {
		var     hoverDetected = false
		if  let      location = currentMouseLocation,
			let             h = hovering, shouldDetectHovering {
			if  let       any = controller?.detectHit(at: location) {
				hoverDetected = h.declareHover(any)
			} else {
				hoverDetected = h.clear()
			}
		}

		return hoverDetected
	}

}

extension ZMapController {

	func detectHover() {
		if  mapView?.detectHover() ?? false {
			setNeedsDisplay()
		}
	}

}

func gUpdateHover() {
	gMapController?.detectHover()

	if  gHelpWindow?.isVisible ?? false, gCurrentHelpMode == .dotMode {
		gHelpDotsExemplarController?.detectHover()
	}
}
