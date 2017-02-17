//
//  ZoneCurve.swift
//  Zones
//
//  Created by Jonathan Sand on 10/31/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


enum ZLineKind: Int {
    case below    = -1
    case straight =  0
    case above    =  1
}


class ZoneCurve: ZView {


    var    kind:  ZLineKind = .straight
    var isInner:       Bool = false
    var  parent: ZoneWidget?
    var   child: ZoneWidget?


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        zlayer.backgroundColor = ZColor.clear.cgColor

        if child != nil {
            updateKind()
            constrain()
            drawCurveIn(dirtyRect)
        }
    }


    func updateKind() {
        if (parent?.widgetZone.count)! > 1 {
            let           dragDot = child?.dragDot.innerDot
            let        textWidget = parent?.textWidget
            let    dragDotCenterY =    dragDot?.convert((   dragDot?.bounds)!, to: parent).center.y
            let textWidgetCenterY = textWidget?.convert((textWidget?.bounds)!, to: parent).center.y
            let             delta = Double(dragDotCenterY! - textWidgetCenterY!)
            let         threshold = gDotHeight / 2.0

            if delta > threshold {
                kind = .above
            } else if delta < -threshold {
                kind = .below
            }
        }
    }


    func constrain() {
        snp.removeConstraints()
        snp.makeConstraints { (make: ConstraintMaker) in
            let halfLineThickness = gLineThickness / 2.0
            let         toggleDot = parent?.toggleDot.innerDot
            let           dragDot = child?   .dragDot.innerDot

            make.right.equalTo((dragDot?.snp.left)!)

            switch kind {
            case .above:
                make   .top.lessThanOrEqualTo((dragDot?.snp.centerY)!).offset(-halfLineThickness)
                make.bottom.equalTo(toggleDot!.snp.top).offset(gLineThickness * 1.5)
                break
            case .straight:
                make.height.equalTo(gLineThickness)
                make.bottom.equalTo(toggleDot!.snp.centerY).offset(halfLineThickness - 0.5)
                make.left.equalTo(toggleDot!.snp.right).offset(-1.0)
                return
            case .below:
                make   .top.equalTo(toggleDot!.snp.bottom).offset(-gLineThickness * 1.5)
                make.bottom.greaterThanOrEqualTo((dragDot?.snp.centerY)!).offset(halfLineThickness)
                break
            }

            make.left.equalTo(toggleDot!.snp.centerX).offset(-halfLineThickness)
        }
    }


    func drawCurveIn(_ dirtyRect: CGRect) {
        if dirtyRect.size.width > 1.0 {
            let toggleHalfHeight = (parent?.toggleDot.innerDot?.bounds.size.height)! / 2.0
            let    dragHalfWidth = (child? .dragDot    .innerDot?.bounds.size.width )! / 2.0
            let            color = (child?.widgetZone.isBookmark)! ? gBookmarkColor : gZoneColor
            var y: CGFloat

            switch kind {
            case .above: y = -dirtyRect.maxY - toggleHalfHeight * 2.0; break
            case .below: y =  dirtyRect.minY;                          break
            case .straight: zlayer.backgroundColor = color.cgColor;   return
            }

            let rect = CGRect(x: dirtyRect.minX, y: y, width: dirtyRect.size.width * 2.0 + dragHalfWidth , height: (dirtyRect.size.height + toggleHalfHeight) * 2.0 )
            let path = ZBezierPath(ovalIn: rect)

            ZColor.clear.setFill()
            color.setStroke()
            path.lineWidth = CGFloat(gLineThickness)
            path.flatness = 0.0001
            path.stroke()
        }
    }
}
