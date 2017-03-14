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

        let s            = gSelectionManager

        if  let     zone = s.dragDropZone, let widget = zone.widget {
            let floating = widget.floatingDropDotRect
            let     rect = widget.convert(floating, to: self)
            let  dotPath = ZBezierPath(ovalIn: rect)

            gDragTargetsColor.setStroke()
            gDragTargetsColor.setFill()
            dotPath.fill()

            let linePath = widget.path(to: floating, in: self)

            thinStroke(linePath)
        }
    }
}
