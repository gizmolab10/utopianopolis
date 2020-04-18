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

	var drawingRubberbandRect: CGRect?
	var showRubberband: Bool { return drawingRubberbandRect != nil && drawingRubberbandRect != .zero }

    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        kClearColor.setFill()
        ZBezierPath(rect: bounds).fill()

        if  let rect = drawingRubberbandRect {
            gActiveColor.lighter(by: 2.0).setStroke()
			let path = ZBezierPath(rect: rect)
			path.addDashes()
			path.stroke()
        }

        if  let    widget = gDragDropZone?.widget {
            let   dotRect = widget.floatingDropDotRect
            let localRect = widget.convert(dotRect, to: self)

            gActiveColor.setFill()
            gActiveColor.setStroke()
            ZBezierPath(ovalIn: localRect).fill()
            widget.drawDragLine(to: dotRect, in: self)
        }
    }

    func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: ZGestureRecognizer) -> Bool {
        if  let e = gGraphController {
            return (gestureRecognizer == e.clickGesture && otherGestureRecognizer == e.movementGesture) ||
				gestureRecognizer == e.edgeGesture
        }

        return false
    }

}
