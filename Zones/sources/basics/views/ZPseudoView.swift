//
//  ZPseudoView.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/23/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

enum ZDrawPhase: String {
	case pLines            = "l"
	case pDotsAndHighlight = "d"

	static let allInOrder: [ZDrawPhase] = [.pLines, .pDotsAndHighlight]
}

class ZPseudoView: NSObject {

	var   absoluteFrame = CGRect.zero
	var       drawnSize = CGSize.zero { didSet { bounds = CGRect(origin: .zero, size: drawnSize) } }
	var          bounds = CGRect.zero
	var           frame = CGRect.zero
	var      identifier = NSUserInterfaceItemIdentifier("")
	var  subpseudoviews = [ZPseudoView] ()
	var superpseudoview : ZPseudoView?
	var      toolTipTag : NSView.ToolTipTag?
	var    absoluteView : ZView?

	override var description: String { return toolTip ?? super.description }
	func draw(_ phase: ZDrawPhase) {} // overridden in all subclasses
	func setFrameSize(_ newSize: NSSize) { frame.size = newSize }

	var toolTip : String? {
		didSet {
			if  toolTip    != nil {
				toolTipTag  = absoluteView?.addToolTip(absoluteFrame, owner: self, userData: nil)
			} else if let t = toolTipTag {
				toolTipTag  = nil

				absoluteView?.removeToolTip(t)
			}
		}
	}

	init(view: ZView?) {
		super.init()

		absoluteView = view
	}

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

	func addSubpseudoview(_ sub: ZPseudoView?) {
		if  let s = sub {
			subpseudoviews.append(s)

			s.superpseudoview = self
		}
	}

}
