//
//  ZRingView.swift
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

struct ZRingRects {
	var one         = CGRect()
	var three       = CGRect()
	var equilateral = [CGRect]()
	var thick       = CGFloat()
}

class ZRingView: ZView {

    let   gradientView  = ZGradientView()
    let   gradientLayer = CAGradientLayer()
	var    tinyDotRects = [Int : CGRect]()
    var confinementRect = CGRect.zero
	func intersectsRing(_ rect: CGRect) -> Bool { return ringRect.intersects(rect) }

	var ringRect : CGRect {
		let rects = ringRects

		return gBrowsingIsConfined ? rects.one : rects.three
	}

	var ringRects : ZRingRects {
		var         result = ZRingRects()
		var           rect = bounds.squareCenetered
		let          inset = rect.size.width / 3.0
		let      ringInset = inset / 3.85
		rect               = rect.insetBy(dx: inset,     dy: inset)
		var          three = rect.insetBy(dx: 0,         dy: inset / 14.0)
		let            one = rect.insetBy(dx: ringInset, dy: ringInset)
		result      .thick = rect.size.height / 30.0
		var         offset =  gInsertionsFollow ? 15.0 - three.minY : bounds.maxY - three.maxY - 15.0
		offset            += (gInsertionsFollow ? -1.0 : 1.0) * ringInset / 1.8
		result        .one = one  .offsetBy(dx: 0.0, dy: offset)
		three              = three.offsetBy(dx: 0.0, dy: offset)
		result      .three = three .insetBy(fractionX: 0.425, fractionY: 0.15)

		return result
	}

	var ringObjects : ZObjectsArray {
		var  ringArray = ZObjectsArray()
		var essayIndex = 0
		var  ideaIndex = 0

		func pluck(from ring: ZObjectsArray) {
			for object in ring {
				if  object.isKind(of: Zone.self) {
					ringArray.append(object)
				} else if let  essay = object as? ZParagraph,
					let idea = essay.zone {

					if  let index = ringArray.firstIndex(of: idea) {
						ringArray[index] = [idea, essay] as NSObject
					} else {
						ringArray.append(object)
					}
				}
			}
		}

		pluck(from: gFocusRing.ring)
		pluck(from: gEssayRing.ring)

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

	func focusItem(containedIn rect: CGRect?) -> NSObject? {
		if  let r = rect {
			let items = ringObjects
			for (index, tinyRect) in tinyDotRects {
				if  items.count > index,
					tinyRect.intersects(r) {
					return items[index]
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
        
        let        rects = ringRects
		var surroundRect = rects.one.insetBy(dx: -6.0, dy: -6.0)
		var       radius = Double(surroundRect.size.width) / 27.0
		let        color = ZColor(ciColor: CIColor(cgColor: gDirectionIndicatorColor))

        color.setStroke()
        gBackgroundColor.setFill()
        
        if  gBrowsingIsConfined {
			confinementRect = rects.one
            ZBezierPath                  .drawCircle (in:   rects.one, thickness: rects.thick)
        } else {
            confinementRect = rects.three
            surroundRect    = ZBezierPath.drawCircles(in: rects.three, thickness: rects.thick, orientedUp: gInsertionsFollow).insetBy(dx: -6.0, dy: -6.0)
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
