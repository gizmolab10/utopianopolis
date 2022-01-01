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

class ZDragView: ZMapView, ZGestureRecognizerDelegate {

	func setup() {
		setup(.mTextAndHighlights)
	}

	override func updateTrackingAreas() {
		super.updateTrackingAreas()
		addTracking(for: bounds)
	}

    override func draw(_ dirtyRect: CGRect) {
        kClearColor.setFill()
        ZBezierPath(rect: bounds).fill() // transparent background
		gRubberband.draw()
		gDragging.dragLine?.drawDragLineAndDot()
	}

	override func mouseExited(with event: ZEvent) {
		super.mouseExited(with: event)

		if  gRubberband.rubberbandRect != nil {
			gRubberband.rubberbandRect  = nil
		}

		if  gDragging.dropWidget != nil {
			gDragging.dropWidget  = nil
		}

		setNeedsDisplay()
	}

}
