//
//  ZoneDragWidget.swift
//  Zones
//
//  Created by Jonathan Sand on 2/16/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneDragWidget: ZView {


    let      line = ZoneCurve()
    let   dragDot = ZoneDot()
    var  relation = ZRelation.upon
    var  location = CGPoint()
    var toggleDot:  ZoneDot?
    var    target:  ZView?
    var     mover:  Zone?
    var     index:  Int?


    func displayFor(iMover: Zone?, at iIndex: Int?, in iRoot: Zone?, with iRelation: ZRelation, locatedAt: CGPoint, in iView: ZView) {
        target       = gWidgetsManager.widgetForZone(iRoot)?.textWidget
        relation     = iRelation
        location     = locatedAt
        index        = iIndex
        mover        = iMover
        needsDisplay = true

//        if line.superview == nil {
//            addSubview(line)
//        }
//
//        if dragDot.superview == nil {
//            addSubview(dragDot)
//        }

        // setup for moving drag dot, root's toggle dot and curved line between them


        if target != nil {
            let frame = convert(target!.bounds, to: iView)

            if  frame.minX < location.x {
                snp.removeConstraints()
                snp.makeConstraints { (make: ConstraintMaker) in
                    make.left.greaterThanOrEqualTo(target!.snp.right)
                    make.right.equalTo(iView).offset(location.x - iView.bounds.maxX)
                    make.top.bottom.equalTo(iView)
                }
            }
        }

        // report("\(relation) \(index!)")

    }


    override func draw(_ dirtyRect: CGRect) {
        addBorder(thickness: 1.0, radius: 20.0, color: ZColor.red.withAlphaComponent(0.2).cgColor)
    }
}
