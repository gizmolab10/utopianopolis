//
//  ZIndicatorView.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 2/16/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

import SnapKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif


enum ZIndicatorType: Int {
    case eConfinement
    case eDirection
}


class ZIndicatorView: ZView {
    
    
    let   gradientView  = ZGradientView()
    let   gradientLayer = CAGradientLayer()
    var confinementRect = CGRect.zero

    
    func setupGradientView() {
        addSubview(gradientView)

        gradientView.zlayer.backgroundColor = kWhiteColor.withAlphaComponent(0.6).cgColor
        gradientView.setup()
    }
    

    func layoutGradientView() {
        gradientView.snp.removeConstraints()
        gradientView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.height.equalTo(bounds.size.height / 5.0)

            if  gInsertionsFollow {
                make.bottom.equalToSuperview()
            } else {
                make.top.equalToSuperview()
            }
        }
        
        gradientView.invertMode = gInsertionsFollow
    }
    
    
    func hitTest(_ rect: CGRect?) -> ZIndicatorType? {
        if  let r = rect,
            gradientView.frame.intersects(r) {
            let (circleRect, circlesRect, _) = rects()
            let    c = gBrowsingIsConfined ? circleRect : circlesRect
            
            return c.intersects(r) ? .eConfinement : .eDirection
        }

        return nil
    }
    
    
    func rects() -> (CGRect, CGRect, CGFloat) {
        var           rect = bounds.squareCenetered
        let          inset = rect.size.width / 3.0
        let    circleInset = inset / 3.85
        rect               = rect.insetBy(dx: inset,       dy: inset)
        var   triangleRect = rect.insetBy(dx: 0,           dy: inset / 14.0)
        var     circleRect = rect.insetBy(dx: circleInset, dy: circleInset)
        let      thickness = rect.size.height / 30.0
        let     multiplier = CGFloat(gInsertionsFollow ? 1 : -1)
        let verticalOffset = gInsertionsFollow ? 15.0 - triangleRect.minY : bounds.maxY - triangleRect.maxY - 15.0
        let   circleOffset = (circleInset / -1.8 * multiplier) + verticalOffset
        triangleRect       = triangleRect.offsetBy(dx: 0.0, dy: circleOffset)
        circleRect         = circleRect  .offsetBy(dx: 0.0, dy: circleOffset)
        let    circlesRect = triangleRect.insetBy(fractionX: 0.425, fractionY: 0.15)

        return (circleRect, circlesRect, thickness)
    }
    
    
    override func draw(_ iDirtyRect: CGRect) {
        super.draw(iDirtyRect)
        
        layoutGradientView()
        
        let (circleRect, circlesRect, thickness) = rects()

        let    strokeColor = ZColor(ciColor: CIColor(cgColor: gDirectionIndicatorColor))
        var   surroundRect = circleRect.insetBy(dx: -6.0, dy: -6.0)
        let      dotsCount = gFocusRing.ring.count
        var         radius = Double(surroundRect.size.width) / 27.0

        strokeColor.setStroke()
        gBackgroundColor.setFill()
        
        if  gBrowsingIsConfined {
            ZBezierPath                  .drawCircle (in: circleRect,  thickness: thickness)
            confinementRect = circleRect
        } else {
            confinementRect = circlesRect
            surroundRect    = ZBezierPath.drawCircles(in: circlesRect, thickness: thickness, orientedUp: gInsertionsFollow).insetBy(dx: -6.0, dy: -6.0)
            radius         /= 2.0
        }

        drawDots(surrounding: surroundRect, count: dotsCount, radius: radius, color: strokeColor, startQuadrant: (gInsertionsFollow ? 1.0 : -1.0))
    }

}


extension ZBezierPath {

    static func drawTriangle(orientedUp: Bool, in iRect: CGRect, thickness: CGFloat) {
        let path = ZBezierPath()
        
        path.appendTriangle(orientedUp: orientedUp, in: iRect)
        path.draw(thickness: thickness)
    }
    
    static func drawCircle(in iRect: CGRect, thickness: CGFloat) {
        let path = ZBezierPath(ovalIn: iRect)
        
        path.draw(thickness: thickness)
    }
    
    static func drawCircles(in iRect: CGRect, thickness: CGFloat, orientedUp: Bool) -> CGRect {
        let path = ZBezierPath()
        let rect = path.appendCircles(orientedUp: orientedUp, in: iRect)

        path.draw(thickness: thickness)
        
        return rect
    }

    func draw(thickness: CGFloat) {
        lineWidth = thickness

        stroke()
        // fill()
    }
    
    func appendTriangle(orientedUp: Bool, in iRect: CGRect) {
        let yStart = orientedUp ? iRect.minY : iRect.maxY
        let   yEnd = orientedUp ? iRect.maxY : iRect.minY
        let    tip = CGPoint(x: iRect.midX, y: yStart)
        let   left = CGPoint(x: iRect.minX, y: yEnd)
        let  right = CGPoint(x: iRect.maxX, y: yEnd)

        move(to: tip)
        line(to: left)
        line(to: right)
        line(to: tip)
    }
    
    func appendCircles(orientedUp: Bool, in iRect: CGRect) -> CGRect {
        let   rect = iRect.offsetBy(fractionX: 0.0, fractionY: orientedUp ? 0.1 : -0.1)
        var    top = rect.insetBy(fractionX: 0.0, fractionY: 0.375)  // shrink to one-fifth size
        let middle = top.offsetBy(dx: 0.0, dy: top.midY - rect.midY)
        let bottom = top.offsetBy(dx: 0.0, dy: top.maxY - rect.maxY) // move to bottom
        top        = top.offsetBy(dx: 0.0, dy: top.minY - rect.minY) // move to top
        
        appendOval(in: top)
        appendOval(in: middle)
        appendOval(in: bottom)
        
        return orientedUp ? top : bottom
    }

}


extension CGRect {
    var squareCenetered: CGRect {
        let length = size.minimumDimension
        let origin = CGPoint(x: minX + (size.width - length) / 2.0, y: minY + (size.height - length) / 2.0)

        return CGRect(origin: origin, size: CGSize(width: length, height: length))
    }
}


extension CGSize {
    
    var minimumDimension: CGFloat {
        return width > height ? height : width
    }

}
