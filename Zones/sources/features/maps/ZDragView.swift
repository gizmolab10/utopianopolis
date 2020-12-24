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

	@IBOutlet var controller: ZMapController?
	override func menu(for event: NSEvent) -> NSMenu? { return controller?.mapContextualMenu }

    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        kClearColor.setFill()
		kClearColor.setStroke()
        ZBezierPath(rect: bounds).fill() // transparent background

		// draw dashed rectangle in active color for rubberband

		if  controller?.isBigMap ?? false,
			let rect = gRubberband.rubberbandRect {
			gActiveColor.accountingForDarkMode.lighter(by: 2.0).setStroke()
			let path = ZBezierPath(rect: rect)
			path.lineWidth = gIsDark ? 3.0 : 2.0
			path.addDashes()
			path.stroke()
        }

		// draw dragged dot and line in active color

		if  let     widget = gDragDropZone?.widget,
			let        dot = widget.revealDot.innerDot,
			let          c = controller, c.isBigMap != gDragDropZone?.isInSmallMap {
			let parameters = widget.widgetZone?.dropDotParameters() ?? ZDotParameters()
            let  floatRect = widget.floatingDropDotRect
            let   dragRect = widget.convert(floatRect, to: self)
			let    dotRect = convert(dot.bounds, from: dot)

			gActiveColor.setFill()
            gActiveColor.setStroke()
			ZBezierPath(ovalIn: dragRect).fill()
			widget.drawDragLine(to: floatRect, in: self)
			dot.drawInnerDot(dotRect, parameters)
        }
	}

    func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: ZGestureRecognizer) -> Bool {
        if  let c = controller {
            return gestureRecognizer == c.clickGesture && otherGestureRecognizer == c.movementGesture
        }

        return false
    }

	override func updateTrackingAreas() {
		for area in trackingAreas {
			removeTrackingArea(area)
		}

		addTrackingArea(NSTrackingArea(rect: bounds, options: [.activeAlways, .cursorUpdate, .mouseEnteredAndExited, .enabledDuringMouseDrag], owner: self, userInfo: nil))
		super.updateTrackingAreas()
	}

	override func mouseExited(with event: NSEvent) {
		super.mouseExited(with: event)

		if  gRubberband.rubberbandRect != nil {
			gRubberband.rubberbandRect  = nil

			setNeedsDisplay()
		}

		if  gDragDropZone != nil {
			gDragDropZone  = nil

			setNeedsDisplay()
		}
	}

}
