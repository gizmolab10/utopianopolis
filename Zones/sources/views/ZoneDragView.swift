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
    var        offset = CGPoint.zero
    var magnification = CGFloat(1.0)


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

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
        let     deltaY = event.deltaY
        let adjustment = exp2(deltaY / 100.0)
        magnification *= adjustment
        offset.x      *= adjustment
        offset.y      *= adjustment
    }


    override func scrollWheel(with event: ZEvent) {
        let isOption = event.modifierFlags.contains(.option)

        if  isOption {
            updateMagnification(with: event)
        } else {
            let multiply = 1.5 / magnification
            offset.x    -= event.deltaX * multiply
            offset.y    += event.deltaY * multiply
        }

        gEditorController?.layoutForCurrentScrollOffset()
        gEditorController?.view.setNeedsDisplay()
        //        contentView.scroll(to: offset)

        // columnarReport(" SCROLL", offset)
    }


    func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: ZGestureRecognizer) -> Bool {
        if  let e = gEditorController {
            return gestureRecognizer == e.clickGesture && otherGestureRecognizer == e.rubberbandGesture
        }

        return false
    }

}
