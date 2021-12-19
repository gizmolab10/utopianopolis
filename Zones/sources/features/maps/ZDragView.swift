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

	let mapView = ZMapView()

	func setup() {
		mapView.zlayer.backgroundColor = ZColor.clear.cgColor

		addSubview(mapView)
		mapView.setup(.mText)
	}

	override func updateTrackingAreas() {
		super.updateTrackingAreas()
		addTracking(for: bounds)
	}

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

		// draw dragging (dot and line) in active color

		if  let      line = gDropLine {
			let floatRect = line.absoluteDropDotRect

			gActiveColor.setFill()
            gActiveColor.setStroke()
			ZBezierPath(ovalIn: floatRect).fill()  // target [floater] dot
			line.drawDragLine(to: floatRect)
        }
	}

	override func mouseExited(with event: ZEvent) {
		super.mouseExited(with: event)

		if  gRubberband.rubberbandRect != nil {
			gRubberband.rubberbandRect  = nil
		}

		if  gDropWidget != nil {
			gDropWidget  = nil
		}

		setNeedsDisplay()
	}

}
