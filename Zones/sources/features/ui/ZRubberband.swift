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
	var rubberbandStart    = CGPoint.zero
	var showRubberband     : Bool { return rubberbandRect != nil && rubberbandRect != .zero }
	func clearRubberband()        { rubberbandStart = .zero }

	var rubberbandRect: CGRect? { // wrapper with new value logic
		didSet {
			if  oldValue != nil, oldValue != .zero, (rubberbandRect == nil || rubberbandRect == .zero) {
				gSelecting.assureMinimalGrabs()
				gSelecting.updateCurrentBrowserLevel()
				gSelecting.updateCousinList()
			}
		}
	}

	@discardableResult func setRubberbandExtent(to extent: CGPoint) -> Bool { // true means rect was set
		if  rubberbandStart != .zero {
			rubberbandRect   = CGRect(start: rubberbandStart, extent: extent)

			return true
		}

		return false
	}

	func updateGrabs() {
		gSelecting.ungrabAll(retaining: rubberbandPreGrabs)
		gHere.ungrab()

		if  let rect = rubberbandRect {
			for widget in gWidgets.visibleWidgets {
				if  let zone = widget.widgetZone, !zone.isSmallMapRoot,
					widget.highlightRect.intersects(rect) {
					gSelecting.addOneGrab(zone)
				}
			}
		}
	}

	func rubberbandStartEvent(_ location: CGPoint, _ iGesture: ZGestureRecognizer?) {
		rubberbandStart = location

		gDragging.draggedZones.removeAll()

		// ///////////////////
		// detect SHIFT key //
		// ///////////////////

		if let gesture = iGesture, gesture.isShiftDown {
			rubberbandPreGrabs.append(contentsOf: gSelecting.currentMapGrabs)
		} else {
			rubberbandPreGrabs.removeAll()
		}

		gTextEditor.stopCurrentEdit()
		gSelecting.ungrabAll(retaining: rubberbandPreGrabs)
	}

	func draw() {
		if  let       rect = rubberbandRect {
			let       path = ZBezierPath(rect: rect)
			path.lineWidth = gIsDark ? 3.0 : 2.0

			gActiveColor.accountingForDarkMode.lighter(by: 2.0).setStroke()
			path.addDashes()
			path.stroke()           // draw dashed rectangle in active color for rubberband
		}
	}
	
}
