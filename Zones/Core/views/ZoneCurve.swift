//
//  ZoneCurve.swift
//  Zones
//
//  Created by Jonathan Sand on 10/31/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneCurve: ZView {


    var    kind:  ZLineKind = .straight
    var isInner:       Bool = false
    var dragDot:    ZoneDot?
    var  widget: ZoneWidget?
    var   inner:  ZoneCurve?


    func setup() {}


    func update() {
        snp.removeConstraints()

        let             offset = stateManager.lineThicknes / 2.0
        let          textField = widget?.textField
        let     dragDotCenterY =   dragDot?.convert((  dragDot?.bounds)!, to: widget).center.y
        let   textFieldCenterY = textField?.convert((textField?.bounds)!, to: widget).center.y
        let              delta = dragDotCenterY! - textFieldCenterY!
        zlayer.backgroundColor = ZColor.clear.cgColor

        if delta > 0.1 {
            kind = .above
        } else if delta < 0.1 {
            kind = .below
        }

        snp.makeConstraints { (make) in
            make.left.equalTo((widget?.toggleDot.snp.centerX)!).offset(-offset)
            make.right.equalTo((dragDot?.snp.left)!)
            switch (kind) {
            case .above:
                make.top.equalTo((dragDot?.snp.centerY)!).offset(-offset)
                make.bottom.equalTo((widget?.toggleDot.innerDot?.snp.top)!)
                break
            case .straight:
                break
            case .below:
                make.top.equalTo((widget?.toggleDot.innerDot?.snp.bottom)!)
                make.bottom.equalTo((dragDot?.snp.centerY)!).offset(offset)
                break
            }
        }
    }


    override func draw(_ dirtyRect: CGRect) {
        update()

        if dirtyRect.size.width > 2.0 {
            var y: CGFloat

            switch kind {
            case .above: y = -dirtyRect.maxY; break
            default:     y =  dirtyRect.minY; break
            }

            let rect = CGRect(x: dirtyRect.minX, y: y, width: dirtyRect.size.width * 2.0, height: dirtyRect.size.height * 2.0)
            let path = ZBezierPath(ovalIn: rect)

            stateManager.lineColor.setStroke()
            ZColor.clear.setFill()
            ZBezierPath.clip(dirtyRect)
            path.lineWidth = stateManager.lineThicknes
            path.flatness = 0.01
            path.stroke()
        }
    }
}
