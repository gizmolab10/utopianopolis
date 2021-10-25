//
//  ZPseudoView.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/23/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

class ZPseudoView: NSObject {

	var   absoluteFrame = CGRect.zero
	var       drawnSize = CGSize.zero
	var          bounds = CGRect.zero
	var           frame = CGRect.zero
	var      identifier = NSUserInterfaceItemIdentifier("")
	var  subpseudoviews = [ZPseudoView] ()
	var superpseudoview : ZPseudoView?
	var         toolTip : String?

	func draw(_ iDirtyRect: CGRect) {}

	func convert(_ point: NSPoint, toContaining view: ZPseudoView?) -> NSPoint {
		if	view != self,
			let s = superpseudoview {
			let f = s.frame
			return s.convert(f.origin + point, toContaining: view) // recurse
		}

		return point
	}

	func convert(_ rect: NSRect, toContaining view: ZPseudoView?) -> NSRect  {
		let o = convert(rect.origin, toContaining: view)

		return CGRect(origin: o, size: rect.size)
	}

	func removeFromSuperpseudoview() {
		if  var siblings = superpseudoview?.subpseudoviews,
			let    index = siblings.firstIndex(of: self) {
			siblings.remove(at: index)

			superpseudoview?.subpseudoviews = siblings
		}
	}

	func updateAbsoluteFrame(toController controller: ZMapController?) {
		if  let      root = controller?.mapPseudoView {
			absoluteFrame = convert(frame, toContaining: root)
		}
	}

	func addSubpseudoview(_ sub: ZPseudoView) { subpseudoviews.append(sub); sub.superpseudoview = self }
	func setFrameSize(_ newSize: NSSize) { frame.size = newSize }

}
