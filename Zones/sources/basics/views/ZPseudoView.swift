//
//  ZPseudoView.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/23/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

enum ZDrawPhase: String {
	case pDots      = "d"
	case pLines     = "l"
	case pHighlight = "h"

	static let allInOrder: [ZDrawPhase] = [.pLines, .pDots, .pHighlight]
}

class ZPseudoView: NSObject {

	var   absoluteFrame = CGRect.zero
	var       drawnSize = CGSize.zero { didSet { bounds = CGRect(origin: .zero, size: drawnSize) } }
	var          bounds = CGRect.zero
	var           frame = CGRect.zero
	var      identifier = NSUserInterfaceItemIdentifier("")
	var  subpseudoviews = [ZPseudoView] ()
	var superpseudoview : ZPseudoView?
	var         toolTip : String?

	func draw(_ phase: ZDrawPhase) {}

	func convert(_ point: NSPoint, toContaining view: ZPseudoView?) -> NSPoint {
		if	view != self,
			let s = superpseudoview {
			let f = s.frame

			return s.convert(f.origin.offsetBy(point), toContaining: view) // recurse
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
