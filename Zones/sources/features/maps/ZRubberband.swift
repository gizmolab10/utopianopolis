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
	var showRubberband: Bool { return rubberbandRect != nil && rubberbandRect != .zero }

	var rubberbandRect: CGRect? { // wrapper with new value logic
		didSet {
			if  rubberbandRect == nil || rubberbandRect == .zero {
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

	func updateGrabs(in iView: ZView?) {
		gSelecting.ungrabAll(retaining: rubberbandPreGrabs)
		gHere.ungrab()

		if  let    view = iView,
			let    rect = rubberbandRect {
			for widget in gWidgets.visibleWidgets {
				if  let    hitRect = widget.hitRect {
					let widgetRect = widget.convert(hitRect, to: view)

					if  let   zone = widget.widgetZone,
						!zone.isFavoritesRoot,
						!zone.isRecentsRoot,
						widgetRect.intersects(rect) {
						gSelecting.addOneGrab(zone)
						widget                  .setNeedsDisplay()
						widget.dragDot.innerDot?.setNeedsDisplay()
					}
				}
			}
		}
	}

	func rubberbandStartEvent(_ location: CGPoint, _ iGesture: ZGestureRecognizer?) {
		rubberbandStart = location
		gDraggedZone    = nil

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

}
