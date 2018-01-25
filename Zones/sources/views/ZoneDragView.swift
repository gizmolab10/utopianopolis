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


class ZoneDragView: ZView, ZGestureRecognizerDelegate {


    var rubberbandRect: CGRect?


    #if os(OSX)

    override func keyDown(with event: NSEvent) {
        textInputReport("main view")
        super.keyDown(with: event)
    }

    #endif


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        kClearColor.setFill()
        ZBezierPath(rect: bounds).fill()

        if  let rect = rubberbandRect {
            gRubberbandColor.lighter(by: 2.0).setStroke()
            ZBezierPath(rect: rect).stroke()
        }

        if  let    widget = gDragDropZone?.widget {
            let   dotRect = widget.floatingDropDotRect
            let localRect = widget.convert(dotRect, to: self)

            gRubberbandColor.setFill()
            gRubberbandColor.setStroke()
            ZBezierPath(ovalIn: localRect).fill()
            widget.drawDragLine(to: dotRect, in: self)
        }
    }


    func updateMagnification(with event: ZEvent) {
        #if os(OSX)
            let      deltaY  = event.deltaY
            let  adjustment  = exp2(deltaY / 100.0)
            gScaling        *= Double(adjustment)
        #endif
    }


    #if os(OSX)
        override func scrollWheel(with event: ZEvent) {
            if  event.modifierFlags.contains(.command) {
                updateMagnification(with: event)
            } else {
                let     multiply = CGFloat(1.5 * gScaling)
                gScrollOffset.x += event.deltaX * multiply
                gScrollOffset.y += event.deltaY * multiply
            }

            gEditorController?.layoutForCurrentScrollOffset()
        }
    #endif


    func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: ZGestureRecognizer) -> Bool {
        if  let e = gEditorController {
            return gestureRecognizer == e.clickGesture && otherGestureRecognizer == e.movementGesture
        }

        return false
    }

}
