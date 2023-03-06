//
//  ZRubberband.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/24/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

let gRubberband = ZRubberband()

class ZRubberband: NSObject {
	var rubberbandPreGrabs = ZoneArray ()
	var showRubberband     : Bool { return rubberbandRect != nil && rubberbandRect != .zero }
	func clearRubberband()        { gDragging.dragStart = .zero }

	var rubberbandRect: CGRect? { // wrapper with new value logic
		didSet {
			if  oldValue != nil, oldValue != .zero, !showRubberband {
				gSelecting.assureMinimalGrabs()
				gSelecting.updateCurrentBrowserLevel()
				gSelecting.updateCousinList()
			}
		}
	}

	@discardableResult func setRubberbandExtent(to extent: CGPoint) -> Bool { // true means rect was set
		if  gDragging.dragStart != .zero {
			rubberbandRect       = CGRect(start: gDragging.dragStart, extent: extent)

			return true
		}

		return false
	}

	func updateGrabs() {
		gSelecting.ungrabAll(retaining: rubberbandPreGrabs)
		gHere.ungrab()

		if  let rect = rubberbandRect {
			for widget in gWidgets.visibleWidgets {
				if  let zone = widget.widgetZone, !zone.isFavoritesRoot,
					widget.highlightRect.intersects(rect) {
					gSelecting.addOneGrab(zone)
				}
			}
		}
	}

	func rubberbandStartEvent(_ gesture: ZGestureRecognizer) {

		// ///////////////////
		// detect SHIFT key //
		// ///////////////////

		if  gesture.isShiftDown {
			rubberbandPreGrabs.append(contentsOf: gSelecting.currentMapGrabs)
		} else {
			rubberbandPreGrabs.removeAll()
		}

		if !gesture.isControlDown {
			gSelecting.ungrabAll(retaining: rubberbandPreGrabs)
		}
	}

	func draw() {
		if  let rect = rubberbandRect {
			gActiveColor.lighter(by: 2.0).setStroke()
			rect.drawRubberband()           // draw dashed rectangle in active color for rubberband
		}
	}
	
}
