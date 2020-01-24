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
	var    tinyDotRects = [Int : CGRect]()
    var confinementRect = CGRect.zero
	func intersectsRing(_ rect: CGRect) -> Bool { return ringRect.intersects(rect) }

	var ringRect : CGRect {
		let (oneRingRect, threeRingsRect, _) = ringRects

		return gBrowsingIsConfined ? oneRingRect : threeRingsRect
	}

	var ringRects : (CGRect, CGRect, CGFloat) {
		var           rect = bounds.squareCenetered
		let          inset = rect.size.width / 3.0
		let      ringInset = inset / 3.85
		rect               = rect.insetBy(dx: inset,     dy: inset)
		var   triangleRect = rect.insetBy(dx: 0,         dy: inset / 14.0)
		var    oneRingRect = rect.insetBy(dx: ringInset, dy: ringInset)
		let      thickness = rect.size.height / 30.0
		let     multiplier = CGFloat(gInsertionsFollow ? 1 : -1)
		let verticalOffset = gInsertionsFollow ? 15.0 - triangleRect.minY : bounds.maxY - triangleRect.maxY - 15.0
		let     ringOffset = (ringInset / -1.8 * multiplier) + verticalOffset
		oneRingRect        = oneRingRect .offsetBy(dx: 0.0, dy: ringOffset)
		triangleRect       = triangleRect.offsetBy(dx: 0.0, dy: ringOffset)
		let threeRingsRect = triangleRect .insetBy(fractionX: 0.425, fractionY: 0.15)

		return (oneRingRect, threeRingsRect, thickness)
	}

	var ringObjects : ZObjectsArray {
		var  ringArray = ZObjectsArray()
		var essayIndex = 0
		var  ideaIndex = 0

		while essayIndex < gEssayRing.ring.count || ideaIndex < gFocusRing.ring.count {
			var essay: AnyObject?
			var focus: AnyObject?

			if  gEssayRing.ring.count > essayIndex {
				essay = gEssayRing.ring[essayIndex]
			}

			if  gFocusRing.ring.count > ideaIndex {
				focus = gFocusRing.ring[ideaIndex]
			}

			if  let idea = focus as? Zone {
				ideaIndex += 1

				if  let e = essay as? ZParagraph, idea == e.zone {
					essayIndex += 1

					ringArray.append([idea, e] as AnyObject)
				} else {
					ringArray.append(idea)
				}
			} else if essay != nil {
				essayIndex += 1

				ringArray.append(essay!)
			}
		}

		return ringArray
	}

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

	func focusItem(containedIn rect: CGRect?) -> AnyObject? {
		if  let r = rect {
			for (index, tinyRect) in tinyDotRects {
				if  tinyRect.intersects(r) {
					return ringObjects[index]
				}
			}
		}

		return nil
	}

    func indicatorType(containedIn rect: CGRect?) -> ZIndicatorType? {
        if  let r = rect, gradientView.frame.intersects(r) {
            return intersectsRing(r) ? .eConfinement : .eDirection
        }

        return nil
    }

    override func draw(_ iDirtyRect: CGRect) {
        super.draw(iDirtyRect)
        
        layoutGradientView()
        
        let (one, three, thick) = ringRects
		var        surroundRect = one.insetBy(dx: -6.0, dy: -6.0)
		var              radius = Double(surroundRect.size.width) / 27.0
		let               color = ZColor(ciColor: CIColor(cgColor: gDirectionIndicatorColor))

        color.setStroke()
        gBackgroundColor.setFill()
        
        if  gBrowsingIsConfined {
			confinementRect = one
            ZBezierPath                  .drawCircle (in:   one, thickness: thick)
        } else {
            confinementRect = three
            surroundRect    = ZBezierPath.drawCircles(in: three, thickness: thick, orientedUp: gInsertionsFollow).insetBy(dx: -6.0, dy: -6.0)
            radius         /= 2.0
        }

		drawTinyDots(surrounding: surroundRect, objects: ringObjects, radius: radius, color: color, startQuadrant: (gInsertionsFollow ? 1.0 : -1.0)) { (index, rect) in
			self.tinyDotRects[index] = rect
		}
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
