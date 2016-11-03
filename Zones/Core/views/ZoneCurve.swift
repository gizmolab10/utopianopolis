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
    var   inner:  ZoneCurve?


    func setup() {}


    func update() {
        snp.removeConstraints()

        let            dragDot = child?.dragDot.innerDot
        let          toggleDot = parent?.toggleDot.innerDot
        let          textField = parent?.textField
        let     dragDotCenterY =   dragDot?.convert((  dragDot?.bounds)!, to: parent).center.y
        let   textFieldCenterY = textField?.convert((textField?.bounds)!, to: parent).center.y
        let  halfLineThickness = stateManager.lineThicknes / 2.0
        let              delta = dragDotCenterY! - textFieldCenterY!
        zlayer.backgroundColor = ZColor.clear.cgColor

        if delta > 0 {
            kind = .above
        } else if delta < 0 {
            kind = .below
        }

        snp.makeConstraints { (make) in
            make .left.equalTo(toggleDot!.snp.centerX).offset(-halfLineThickness)
            make.right.equalTo((dragDot?.snp.left)!)
            switch (kind) {
            case .above:
                make   .top.equalTo((dragDot?.snp.centerY)!).offset(-halfLineThickness)
                make.bottom.equalTo(toggleDot!.snp.centerY)
                break
            case .straight:
                make   .top.equalTo(toggleDot!.snp.centerY).offset( halfLineThickness)
                make.bottom.equalTo(toggleDot!.snp.centerY).offset(-halfLineThickness)
                break
            case .below:
                make   .top.equalTo(toggleDot!.snp.centerY)
                make.bottom.equalTo((dragDot?.snp.centerY)!).offset(halfLineThickness)
                break
            }
        }
    }


    override func draw(_ dirtyRect: CGRect) {
        #if os(OSX)
        update()

        if dirtyRect.size.width > 1.0 {
            var y: CGFloat

            switch kind {
            case .straight: zlayer.backgroundColor = stateManager.lineColor.cgColor; return
            case .above: y = -dirtyRect.maxY; break
            case .below: y =  dirtyRect.minY; break
            }

            let rect = CGRect(x: dirtyRect.minX, y: y, width: dirtyRect.size.width * 2.0, height: dirtyRect.size.height * 2.0)
            let path = ZBezierPath(ovalIn: rect)

            stateManager.lineColor.setStroke()
            ZColor.clear.setFill()
            path.lineWidth = stateManager.lineThicknes
            path.flatness = 0.01
            path.stroke()
        }
        #endif
    }
}
