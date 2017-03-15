//
//  ZonesDrawView.swift
//  Zones
//
//  Created by Jonathan Sand on 3/12/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZonesDrawView: ZView {


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        if  let      zone = gSelectionManager.dragDropZone, let widget = zone.widget {
            let floatRect = widget.floatingDropDotRect
            let  ovalRect = widget.convert(floatRect, to: self)
            let   hitRect = widget.dragHitFrame

            gDragTargetsColor.setFill()
            gDragTargetsColor.setStroke()
            thinStroke(ZBezierPath(rect: hitRect))
            ZBezierPath(ovalIn: ovalRect).fill()
            thinStroke(widget.linePath(to: floatRect, in: self))
        }
    }
}
