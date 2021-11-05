//
//  ZMapView.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/27/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

enum ZMapID: String {
	case mHighlight    = "h"
	case mText         = "t"
	case mDotsAndLines = "m"
}

class ZMapView: ZView {

	var mapID            : ZMapID?
	var dotsAndLinesView : ZMapView?
	var highlightMapView : ZMapView?
	override func menu(for event: ZEvent) -> ZMenu? { return gMapController?.mapContextualMenu }

	func debugDraw() {
		bounds                 .insetEquallyBy(1.5).drawColoredRect(ZColor.blue)    // too small
		dotsAndLinesView?.frame.insetEquallyBy(3.0).drawColoredRect(ZColor.red)     // too tall, too narrow
		highlightMapView?.frame.insetEquallyBy(4.5).drawColoredRect(ZColor.purple)  //    ",        "
		superview?.drawBox(in: self, with:                          ZColor.orange)  // height too small
	}

	func updateFrames(with controller: ZMapController?) {
		if  let   widget = controller?.rootWidget,
			let isBigMap = controller?.isBigMap, !isBigMap {
			var   origin = gDetailsController?.view(for: .vSmallMap)?.frame.origin ?? .zero
			var     rect = widget.frame
			origin    .x = 8.0
			rect .origin = origin
			widget.frame = rect
		}
	}

	override func draw(_ iDirtyRect: CGRect) {
		switch mapID {
			case .mText:
				super            .draw(iDirtyRect)
				dotsAndLinesView?.draw(iDirtyRect)
				highlightMapView?.draw(iDirtyRect)
			default:
				for phase in ZDrawPhase.allInOrder {
					ZBezierPath(rect: iDirtyRect).setClip()

					if  (phase == .pDotsAndHighlight) != (mapID == .mDotsAndLines) {
						gMapController?     .drawWidgets(for: phase)
						gSmallMapController?.drawWidgets(for: phase)
					}
				}
		}
	}

	func setup(_ id: ZMapID = .mText, mapController: ZMapController) {
		mapID = id

		if  id != .mText {
			zlayer.backgroundColor = CGColor.clear
			bounds                 = superview!.bounds
		} else {
			dotsAndLinesView       = ZMapView()
			highlightMapView       = ZMapView()

			updateTracking()
			addSubview(dotsAndLinesView!)
			addSubview(highlightMapView!)
			dotsAndLinesView?.setup(.mDotsAndLines, mapController: mapController)
			highlightMapView?.setup(.mHighlight,    mapController: mapController)
		}
	}

	func removeAllTextViews() {
		for subview in subviews {
			if  let textView = subview as? ZoneTextWidget {
				textView.removeFromSuperview()
			}
		}
	}

	// MARK:- hover
	// MARK:-

	func updateTracking() { addTracking(for: frame) }

}
