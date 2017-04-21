//
//  ZDragDrawView.swift
//  Zones
//
//  Created by Jonathan Sand on 3/12/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZDragDrawView: ZView {


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        if  let    widget = gSelectionManager.dragDropZone?.widget {
            let   dotRect = widget.floatingDropDotRect
            let localRect = widget.convert(dotRect, to: self)

            gDragTargetsColor.setFill()
            gDragTargetsColor.setStroke()
            ZBezierPath(ovalIn: localRect).fill()
            widget.drawDragLine(to: dotRect, in: self)
        }
    }
}
