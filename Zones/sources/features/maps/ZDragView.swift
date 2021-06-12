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

	override func updateTrackingAreas() { addTracking(for: bounds) }

    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        kClearColor.setFill()
		kClearColor.setStroke()
        ZBezierPath(rect: bounds).fill() // transparent background

		// draw dashed rectangle in active color for rubberband

		if  let rect = gRubberband.rubberbandRect {
			gActiveColor.accountingForDarkMode.lighter(by: 2.0).setStroke()
			let path = ZBezierPath(rect: rect)
			path.lineWidth = gIsDark ? 3.0 : 2.0
			path.addDashes()
			path.stroke()
        }

		// draw dragged dot and line in active color

		if  let     widget = gDropZone?.widget,
			let        dot = widget.revealDot.innerDot {
			let parameters = gDropZone?.dropDotParameters() ?? ZDotParameters()
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

	override func mouseExited(with event: ZEvent) {
		super.mouseExited(with: event)

		if  gRubberband.rubberbandRect != nil {
			gRubberband.rubberbandRect  = nil
		}

		if  gDropZone != nil {
			gDropZone  = nil
		}

		setNeedsDisplay()
	}

}
