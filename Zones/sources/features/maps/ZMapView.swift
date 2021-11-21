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
		bounds                 .insetEquallyBy(1.5).drawColoredRect(.blue)    // too small
		dotsAndLinesView?.frame.insetEquallyBy(3.0).drawColoredRect(.red)     // too tall, too narrow
		highlightMapView?.frame.insetEquallyBy(4.5).drawColoredRect(.purple)  //    ",        "
		superview?.drawBox(in: self, with:                          .orange)  // height too small
	}

	override func draw(_ iDirtyRect: CGRect) {
		if  iDirtyRect.isEmpty {
			return
		}

		switch mapID {
			case .mText:
				super            .draw(iDirtyRect)
				dotsAndLinesView?.draw(iDirtyRect)
				highlightMapView?.draw(iDirtyRect)
			default:
				super            .draw(iDirtyRect)
				for phase in ZDrawPhase.allInOrder {
					if  (phase == .pDotsAndHighlight) != (mapID == .mDotsAndLines) {
						ZBezierPath(rect: iDirtyRect).setClip()

						switch mapID {
							case .mDotsAndLines: dotsAndLinesView?.clearRect(iDirtyRect)
							case .mHighlight:    highlightMapView?.clearRect(iDirtyRect)
							default:             break
						}

						gMapController?     .drawWidgets(for: phase)
						gSmallMapController?.drawWidgets(for: phase)
					}
				}
		}
	}

	func clearRect(_ iDirtyRect: CGRect) {
		if  iDirtyRect.isEmpty {
			return
		}

		gBackgroundColor.setFill()
		ZBezierPath(rect: iDirtyRect).fill()
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

	func clear(forSmallMapOnly: Bool = false) {
		if  mapID == .mText {
			highlightMapView?.clear()
			dotsAndLinesView?.clear()

			removeAllTextViews(forSmallMap: forSmallMapOnly)
		}
	}

	func removeAllTextViews(forSmallMap: Bool) {
		for subview in subviews {
			if  let textView = subview as? ZoneTextWidget,
				let inBig = textView.widgetZone?.isInBigMap {
				if  !(forSmallMap && inBig) {
					textView.removeFromSuperview()
				}
			}
		}
	}

	// MARK:- hover
	// MARK:-

	func updateTracking() { addTracking(for: frame) }

}
