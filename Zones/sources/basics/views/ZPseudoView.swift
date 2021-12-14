//
//  ZPseudoView.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/23/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation
import Cocoa

enum ZDrawPhase: String {
	case pLines            = "l"
	case pDotsAndHighlight = "d"

	static let allInOrder: [ZDrawPhase] = [.pLines, .pDotsAndHighlight]
}

class ZPseudoView: NSObject {

	var   absoluteFrame = CGRect .zero
	var          bounds = CGRect .zero
	var           frame = CGRect .zero
	var       drawnSize = CGSize .zero { didSet { bounds = CGRect(origin: .zero, size: drawnSize) } }
	var      identifier = NSUserInterfaceItemIdentifier("")
	var  subpseudoviews = [ZPseudoView] ()
	var superpseudoview : ZPseudoView?
	var      controller : ZMapController? { return nil }
	var      toolTipTag : NSView.ToolTipTag?
	var    absoluteView : ZView?
	var       drawnView : ZView?
	var            mode : ZMapLayoutMode { return controller?.mapLayoutMode ?? .linearMode }
	var    isLinearMode : Bool { return mode == .linearMode }
	var  isCircularMode : Bool { return mode == .circularMode }

	override var description: String { return toolTip ?? super.description }
	func draw(_ phase: ZDrawPhase) {} // overridden in all subclasses
	func setFrameSize(_ newSize: NSSize) { frame.size = newSize }
	func setupDrawnView() { drawnView = absoluteView }

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

		setupDrawnView()
	}

	func convertPoint(_ point: NSPoint, toRootPseudoView view: ZPseudoView?) -> NSPoint {
		if	let s = superpseudoview, s != self, view != self {
			let p = point + s.frame.origin

			return s.convertPoint(p, toRootPseudoView: view) // recurse
		}

		return point
	}

	func convertRect(_ rect: NSRect, toRootPseudoView pseudoView: ZPseudoView?) -> NSRect  {
		let o = convertPoint(rect.origin, toRootPseudoView: pseudoView)

		return CGRect(origin: o, size: rect.size)
	}

	func removeFromSuperpseudoview() {
		if  var siblings = superpseudoview?.subpseudoviews,
			let    index = siblings.firstIndex(of: self) {
			siblings.remove(at: index)

			superpseudoview?.subpseudoviews = siblings
		}
	}

	func updateAbsoluteFrame(relativeTo controller: ZMapController?) {
		if  let      root = controller?.mapPseudoView {
			absoluteFrame = convertRect(frame, toRootPseudoView: root)
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

}
