//
//  ZDragView.swift
//  Seriously
//
//  Created by Jonathan Sand on 8/17/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

class ZDragView: ZView, ZGestureRecognizerDelegate {

	@IBOutlet var controller: ZGraphController?
	var drawingRubberbandRect: CGRect?
	var rubberbandStart = CGPoint.zero
	var rubberbandPreGrabs = ZoneArray ()
	var showRubberband: Bool { return drawingRubberbandRect != nil && drawingRubberbandRect != .zero }

	var rubberbandRect: CGRect? { // wrapper with new value logic
		get {
			return drawingRubberbandRect
		}

		set {
			drawingRubberbandRect = newValue

				if  newValue == nil || newValue == .zero {
					gSelecting.assureMinimalGrabs()
					gSelecting.updateCurrentBrowserLevel()
					gSelecting.updateCousinList()
				} else {
					gSelecting.ungrabAll(retaining: rubberbandPreGrabs)
					gHere.ungrab()

					for widget in gWidgets.visibleWidgets {
						if  let    hitRect = widget.hitRect {
							let widgetRect = widget.convert(hitRect, to: self)

							if  let   zone = widget.widgetZone, !zone.isRootOfFavorites,
								widgetRect.intersects(newValue!) {
								widget.widgetZone?.addToGrab()
							}
						}
					}
				}

				setAllSubviewsNeedDisplay()

		}
	}

	func rubberbandStartEvent(_ location: CGPoint, _ iGesture: ZGestureRecognizer?) {
		rubberbandStart = location
		gDraggedZone    = nil

		// ///////////////////
		// detect SHIFT key //
		// ///////////////////

		if let gesture = iGesture, gesture.isShiftDown {
			rubberbandPreGrabs.append(contentsOf: gSelecting.currentGrabs)
		} else {
			rubberbandPreGrabs.removeAll()
		}

		gTextEditor.stopCurrentEdit()
		gSelecting.ungrabAll(retaining: rubberbandPreGrabs)
	}

    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        kClearColor.setFill()
        ZBezierPath(rect: bounds).fill()
		gActiveColor.lighter(by: 2.0).setStroke()
//		ZBezierPath.drawBloatedTriangle(aimedRight: true, in: bounds.insetEquallyBy(100.0), thickness: 5.0)

        if  let rect = drawingRubberbandRect {
            gActiveColor.lighter(by: 2.0).setStroke()
			let path = ZBezierPath(rect: rect)
			path.addDashes()
			path.stroke()
        }

		if  let    widget = gDragDropZone?.widget, gDragDropZone!.isInMap == controller?.isMap {
            let   dotRect = widget.floatingDropDotRect
            let localRect = widget.convert(dotRect, to: self)

            gActiveColor.setFill()
            gActiveColor.setStroke()
            ZBezierPath(ovalIn: localRect).fill()
            widget.drawDragLine(to: dotRect, in: self)
        }
	}

    func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: ZGestureRecognizer) -> Bool {
        if  let c = controller {
            return (gestureRecognizer == c.clickGesture && otherGestureRecognizer == c.movementGesture) ||
				gestureRecognizer == c.edgeGesture
        }

        return false
    }

}
