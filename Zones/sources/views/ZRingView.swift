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

struct ZRingRects {
	var one   =  CGRect()
	var three =  CGRect()
	var thick =  CGFloat()
}

class ZRingView: ZView {

	var necklaceDotRects = [Int : CGRect]()

	var ringRect : CGRect {
		let rects = necklaceRects

		return gBrowsingIsConfined ? rects.one : rects.three
	}

	func item(containedIn iRect: CGRect?) -> NSObject? {
		if  let    rect = iRect {
			let objects = necklaceObjects 	// expensive computation: do once
			let   count = objects.count

			for (index, tinyRect) in necklaceDotRects {
				if  index < count,
					rect.intersects(tinyRect) {
					return objects[index]
				}
			}

			for (index, controlRect) in controlRects.enumerated() {
				if  rect.intersectsOval(within: controlRect) {
					return ZRingControl.controls[index]
				}
			}
		}

		return nil
	}

	// MARK:- necklace
	// MARK:-

	var necklaceRects : ZRingRects {
		var         result = ZRingRects()
		var           rect = bounds.squareCentered
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

	var necklaceObjects : ZObjectsArray {
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

	// MARK:- controls
	// MARK:-

	var controlRects : [CGRect] {
		let   rect = necklaceRects.one
		let radius = rect.width / 4.5
		let offset = rect.width / 3.5
		let center = rect.center
		var result = [CGRect]()

		for index in 0 ... 2 {
			let angle = .pi / -1.5 * (Double(index) - 0.75)
			let x = center.x + (offset * CGFloat(cos(angle)))
			let y = center.y + (offset * CGFloat(sin(angle)))
			let control = NSRect(origin: CGPoint(x: x, y: y), size: CGSize()).insetBy(dx: -radius, dy: -radius)

			result.append(control)
		}

		return result
	}

	func respondToRingControl(_ item: NSObject) -> Bool {
		if  let control = item as? ZRingControl {
			return control.response()
		}

		return false
	}

	func focusOnIdea(_ item: NSObject) -> Bool {
		if  let idea = item as? Zone {
			gFocusRing.focusOn(idea) {
				print(idea.zoneName ?? "unknown zone")
				gControllers.signalFor(idea, regarding: .eRelayout)
			}

			return true
		}

		return false
	}

	func focusOnEssay(_ item: NSObject) -> Bool {
		if  let            essay = item as? ZParagraph {
			gCurrentEssay        = essay
			gCreateMultipleEssay = true

			gControllers.swapGraphAndEssay()
			print(essay.zone?.zoneName ?? "unknown essay")

			return true
		}

		return false
	}

	@discardableResult func respondToClick(in rect: CGRect?) -> Bool {
		func respond(to item: NSObject) -> Bool {
			return focusOnIdea(item) || focusOnEssay(item)
		}

		if  let item = self.item(containedIn: rect) {
			if  respond(to: item) || respondToRingControl(item) {
				return true
			} else if let subitems = item as? ZObjectsArray {
				for subitem in subitems {
					if  respond(to: subitem) {
						return true
					}
				}
			}
		}

		return false
	}

	// MARK:- render
	// MARK:-

    override func draw(_ iDirtyRect: CGRect) {
        super.draw(iDirtyRect)

        let rects = necklaceRects
		let color = ZColor(ciColor: CIColor(cgColor: gDirectionIndicatorColor))

		color.setStroke()
		gBackgroundColor.setFill()

		if !gFullRingIsVisible {
			ZBezierPath.drawCircle(in: controlRects[0], thickness: rects.thick)
		} else {
			var surroundRect = rects.one.insetBy(dx: -6.0, dy: -6.0)
			var       radius = Double(surroundRect.size.width) / 27.0

			if  gBrowsingIsConfined {
				ZBezierPath               .drawCircle (in:   rects.one, thickness: rects.thick)
			} else {
				surroundRect = ZBezierPath.drawCircles(in: rects.three, thickness: rects.thick, orientedUp: gInsertionsFollow).insetBy(dx: -6.0, dy: -6.0)
				radius      /= 2.0
			}

			drawTinyDots(surrounding: surroundRect, objects: necklaceObjects, radius: radius, color: color, startQuadrant: (gInsertionsFollow ? 1.0 : -1.0)) { (index, rect) in
				self.necklaceDotRects[index] = rect
			}

			for controlRect in controlRects {
				ZBezierPath.drawCircle(in: controlRect, thickness: rects.thick)
			}
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
    var squareCentered: CGRect {
        let length = size.minimumDimension
        let origin = CGPoint(x: minX + (size.width - length) / 2.0, y: minY + (size.height - length) / 2.0)

        return CGRect(origin: origin, size: CGSize(width: length, height: length))
    }

	func intersectsOval(within other: CGRect) -> Bool {
		let center =  other.center
		let radius = (other.height + other.width) / 4.0
		let deltaX = center.x - max(minX, min(center.x, maxX))
		let deltaY = center.y - max(minY, min(center.y, maxY))
		let  delta = radius - sqrt(deltaX * deltaX + deltaY * deltaY)

		print(delta)

		return delta > 0
	}
}

extension CGSize {
    
    var minimumDimension: CGFloat {
        return width > height ? height : width
    }

}
