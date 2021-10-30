//
//  ZMapView.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/27/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

enum ZMapID: String {
	case mHighlight = "h"
	case mText = "t"
	case mMap = "m"
}

class ZMapView: ZView {

	var mapID            : ZMapID?
	var controller       : ZMapController?
	var mapMapView       : ZMapView?
	var highlightMapView : ZMapView?
	override func menu(for event: ZEvent) -> ZMenu? { return controller?.mapContextualMenu }

	override func draw(_ iDirtyRect: CGRect) {
		switch mapID {
			case .mText:
				super            .draw(iDirtyRect)
				mapMapView?      .draw(iDirtyRect)
				highlightMapView?.draw(iDirtyRect)
			default:
				for phase in ZDrawPhase.allInOrder {
					ZBezierPath(rect: iDirtyRect).setClip()

					if  (phase == .pDots) != (mapID == .mMap) {
						controller?.rootWidget?.traverseAllProgeny(inReverse: false) { iWidget in
							iWidget.draw(phase)
						}
					}
				}
		}
	}

	func setup(_ id: ZMapID = .mText, mapController: ZMapController) {
		controller = mapController
		mapID      = id

		if  id != .mText {
			zlayer.backgroundColor = CGColor.clear
			bounds                 = superview!.bounds
		} else {
			mapMapView             = ZMapView()
			highlightMapView       = ZMapView()

			updateTracking()
			addSubview(mapMapView!)
			addSubview(highlightMapView!)
			mapMapView?      .setup(.mMap,       mapController: controller!)
			highlightMapView?.setup(.mHighlight, mapController: controller!)
		}
	}

	// MARK:- hover
	// MARK:-

	func updateTracking() { addTracking(for: frame) }

	override func mouseMoved(with event: ZEvent) {
		super.mouseMoved(with: event)

		let location = convert(event.locationInWindow, from: nil)

		controller?.detectHover(at: location)?.setNeedsDisplay()
	}

}
