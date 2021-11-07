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

	var needsClear       = false
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
		if  let   root = controller?.rootWidget {
			root.frame = CGRect(origin: .zero, size: root.drawnSize)
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

	func clear() {
		if  mapID == .mText {
			highlightMapView?.needsClear = true
			dotsAndLinesView?.needsClear = true

			removeAllTextViews()
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
