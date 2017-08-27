//
//  ZoneDragView.swift
//  Zones
//
//  Created by Jonathan Sand on 8/17/17.
//  Copyright © 2017 Zones. All rights reserved.
//


#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneDragView: NSView, ZGestureRecognizerDelegate {


    var rubberbandRect: CGRect?


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

//        let        scale = CGFloat(gScaling)
//        zlayer.transform = CATransform3DMakeScale(scale, scale, 1.0)

        if  let rect = rubberbandRect {
            gClearColor.setFill()
            gDragTargetsColor.lighter(by: 2.0).setStroke()
            ZBezierPath(rect: rect).stroke()
        }

        if  let    widget = gSelectionManager.dragDropZone?.widget {
            let   dotRect = widget.floatingDropDotRect
            let localRect = widget.convert(dotRect, to: self)

            gDragTargetsColor.setFill()
            gDragTargetsColor.setStroke()
            ZBezierPath(ovalIn: localRect).fill()
            widget.drawDragLine(to: dotRect, in: self)
        }
    }


    func updateMagnification(with event: ZEvent) {
        let      deltaY  = event.deltaY
        let  adjustment  = exp2(deltaY / 100.0)
        gScaling        *= Double(adjustment)
    }


    override func scrollWheel(with event: ZEvent) {
        if  event.modifierFlags.contains(.command) {
            updateMagnification(with: event)
        } else {
            let     multiply = CGFloat(1.5 * gScaling)
            gScrollOffset.x += event.deltaX * multiply
            gScrollOffset.y += event.deltaY * multiply
        }

        gEditorController?.layoutForCurrentScrollOffset()
        gEditorView?.setNeedsDisplay()
    }


    func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: ZGestureRecognizer) -> Bool {
        if  let e = gEditorController {
            return gestureRecognizer == e.clickGesture && otherGestureRecognizer == e.movementGesture
        }

        return false
    }

}
