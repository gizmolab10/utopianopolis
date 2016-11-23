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
    var  parent: ZoneWidget?
    var   child: ZoneWidget?


    override func draw(_ dirtyRect: CGRect) {
        zlayer.backgroundColor = ZColor.clear.cgColor

        updateKind()
        constrain()
        drawCurveIn(dirtyRect)
    }


    func updateKind() {
        if (parent?.widgetZone.children.count)! > 1 {
            let          dragDot = child?.dragDot!.innerDot
            let        textField = parent?.textField
            let   dragDotCenterY =   dragDot?.convert((  dragDot?.bounds)!, to: parent).center.y
            let textFieldCenterY = textField?.convert((textField?.bounds)!, to: parent).center.y
            let            delta = dragDotCenterY! - textFieldCenterY!

            if delta > 2.0 {
                kind = .above
            } else if delta < -2.0 {
                kind = .below
            }
        }
    }


    func constrain() {
        snp.removeConstraints()
        snp.makeConstraints { (make) in
            let halfLineThickness = stateManager.lineThicknes / 2.0
            let         toggleDot = parent?.toggleDot!.innerDot
            let           dragDot = child?.dragDot!.innerDot

            make.right.equalTo((dragDot?.snp.left)!)

            switch (kind) {
            case .above:
                make   .top.lessThanOrEqualTo((dragDot?.snp.centerY)!).offset(-halfLineThickness)
                make.bottom.equalTo(toggleDot!.snp.top)
                break
            case .straight:
                make.height.equalTo(stateManager.lineThicknes)
                make.bottom.equalTo(toggleDot!.snp.centerY)
                make.left.equalTo(toggleDot!.snp.right)
                return
            case .below:
                make   .top.equalTo(toggleDot!.snp.bottom)
                make.bottom.greaterThanOrEqualTo((dragDot?.snp.centerY)!).offset(halfLineThickness)
                break
            }

            make.left.equalTo(toggleDot!.snp.centerX).offset(-halfLineThickness)
        }
    }


    func drawCurveIn(_ dirtyRect: CGRect) {
        if dirtyRect.size.width > 1.0 {
            let toggleHalfHeight = (parent?.toggleDot!.innerDot?.bounds.size.height)! / 2.0
            let    dragHalfWidth = (child? .dragDot!  .innerDot?.bounds.size.width )! / 2.0
            var y: CGFloat

            switch kind {
            case .above: y = -dirtyRect.maxY - toggleHalfHeight * 2.0; break
            case .below: y =  dirtyRect.minY; break
            case .straight: zlayer.backgroundColor = stateManager.lineColor.cgColor; return
            }

            let rect = CGRect(x: dirtyRect.minX, y: y, width: dirtyRect.size.width * 2.0 + dragHalfWidth , height: (dirtyRect.size.height + toggleHalfHeight) * 2.0 )
            let path = ZBezierPath(ovalIn: rect)

            ZColor.clear.setFill()
            stateManager.lineColor.setStroke()
            path.lineWidth = stateManager.lineThicknes
            path.flatness = 0.0001
            path.stroke()
        }
    }
}
