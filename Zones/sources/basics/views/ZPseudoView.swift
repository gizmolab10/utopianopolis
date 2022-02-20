//
//  ZPseudoView.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/23/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

enum ZDrawPhase: String {
	case pLines      = "l"
	case pHighlights = "h"
	case pDots       = "d"
}

class ZPseudoView: NSObject {

	var      isHovering = false
	var   absoluteFrame = CGRect.zero
	var absoluteHitRect = CGRect.zero
	var          bounds = CGRect.zero
	var           frame = CGRect.zero
	var       drawnSize = CGSize.zero { didSet { bounds = CGRect(origin: .zero, size: drawnSize) } }
	var      identifier = NSUserInterfaceItemIdentifier("")
	var  subpseudoviews = [ZPseudoView] ()
	var superpseudoview : ZPseudoView?
	var      toolTipTag : ZToolTipTag?
	var    absoluteView : ZView?
	var       drawnView : ZView?
	var      controller : ZMapController? { return nil }
	var            mode : ZMapLayoutMode  { return controller?.mapLayoutMode ?? .linearMode }
	var      dotPlusGap : CGFloat         { return gDotWidth + gapDistance }
	var     gapDistance : CGFloat         { return (isBigMap ? gBigFontSize : gSmallFontSize) * 0.6 }
	var        isBigMap : Bool            { return controller?.isBigMap ?? true }
	var    isLinearMode : Bool            { return mode == .linearMode }
	var  isCircularMode : Bool            { return mode == .circularMode }

	override var description: String { return toolTip ?? super.description }
	func draw(_ phase: ZDrawPhase) {} // overridden in all subclasses
	func setFrameSize(_ newSize: NSSize) { frame.size = newSize }
	func setupDrawnView() { drawnView = absoluteView }

	func debug(_ rect: CGRect, _ message: String = kEmpty) {}

	var toolTip : String? {
		didSet {
			if  let t = toolTipTag {
				absoluteView?.removeToolTip(t)
			}

			if  toolTip   != nil {
				toolTipTag = absoluteView?.addToolTip(absoluteFrame, owner: self, userData: nil)
			} else {
				toolTipTag = nil
			}

			absoluteView?.addTracking(for: absoluteFrame)
		}
	}

	init(view: ZView?) {
		super.init()

		absoluteView = view

		setupDrawnView()
	}

	func convertPoint(_ point: NSPoint, toRootPseudoView view: ZPseudoView?) -> NSPoint {
		if	let s = superpseudoview, s != self, view != self {
			if  s == view, controller?.isExemplar ?? false {
				return point
			}

			let p = point + s.frame.origin

			return s.convertPoint(p, toRootPseudoView: view) // recurse
		}

		return point
	}

	func convertRect(_ rect: NSRect, toRootPseudoView pseudoView: ZPseudoView?) -> NSRect  {
		let o = convertPoint(rect.origin, toRootPseudoView: pseudoView)

		return CGRect(origin: o, size: rect.size)
	}

	func relayoutAbsoluteFrame(relativeTo controller: ZMapController?) {
		if  let       map = controller?.mapPseudoView {
			absoluteFrame = convertRect(frame, toRootPseudoView: map)
//			debug(absoluteFrame, "FRAME")
		}
	}

	func addSubpseudoview(_ sub: ZPseudoView?) {
		if  let s = sub {
			subpseudoviews.append(s)

			s.superpseudoview = self
		}
	}

	func removeAllSubpseudoviews() {
		var index   = subpseudoviews.count
		while index > 0 {
			index  -= 1

			subpseudoviews.remove(at: index)
		}
	}

	func removeFromSuperpseudoview() {
		if  var siblings = superpseudoview?.subpseudoviews,
			let    index = siblings.firstIndex(of: self) {
			siblings.remove(at: index)

			superpseudoview?.subpseudoviews = siblings
		}
	}

}
