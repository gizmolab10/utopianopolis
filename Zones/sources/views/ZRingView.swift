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

struct ZRingGeometry {
	var one   =  CGRect()
	var thick =  CGFloat()
}

class ZRingView: ZView {

	var necklaceDotRects = [Int : CGRect]()

	// MARK:- draw
	// MARK:-

	func drawControl(for index: Int) {
		ZRingControl.controls[index].draw(controlRects[index])
	}

	override func draw(_ iDirtyRect: CGRect) {
		super.draw(iDirtyRect)

		let color = ZColor(ciColor: CIColor(cgColor: gDirectionIndicatorColor))

		color.setStroke()
		gBackgroundColor.setFill()

		if !gFullRingIsVisible {
			drawControl(for: 1)
		} else {
			let            g = ringGeometry
			let         rect = g.one
			let surroundRect = rect.insetBy(dx: -6.0, dy: -6.0)
			let       radius = Double(surroundRect.size.width) / 27.0

			ZBezierPath.drawCircle (in: rect, thickness: g.thick)

			drawTinyDots(surrounding: surroundRect, objects: necklaceObjects, radius: radius, color: color, startQuadrant: (gInsertionsFollow ? 1.0 : -1.0)) { (index, rect) in
				self.necklaceDotRects[index] = rect
			}

			for index in 0 ... (controlRects.count - 1) {
				drawControl(for: index)
			}
		}
	}

	// MARK:- respond
	// MARK:-

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

	// MARK:- necklace
	// MARK:-

	var ringGeometry  : ZRingGeometry {
		var    result = ZRingGeometry()
		var      rect = bounds.squareCentered
		let     inset = rect.size.width / 3.0
		let ringInset = inset / 3.85
		rect          = rect.insetBy(dx: inset,     dy: inset)
		let     three = rect.insetBy(dx: 0,         dy: inset / 14.0)
		let       one = rect.insetBy(dx: ringInset, dy: ringInset)
		result .thick = rect.size.height / 30.0
		let    offset = bounds.maxY - three.maxY - 15.0 + ringInset / 1.8
		result   .one = one  .offsetBy(dx: 0.0, dy: offset)

		return result
	}

	var necklaceObjects : ZObjectsArray {
		var ringArray = ZObjectsArray()

		func objects(in ring: ZObjectsArray) {
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

		objects(in: gFocusRing.ring)
		objects(in: gEssayRing.ring)

		return ringArray
	}

	// MARK:- controls
	// MARK:-

	var controlRects : [CGRect] {
		let   rect = ringGeometry.one
		let radius = rect.width / 4.5
		let offset = rect.width / 3.5
		let center = rect.center
		var result = [CGRect]()

		for index in 0 ... 2 {
			let increment = 2.0 * .pi / 4.0 	// 1/4 of circle (2 pi)
			let     angle = (2.0 - Double(index)) * increment
			let         x = center.x + (offset * CGFloat(cos(angle)))
			let         y = center.y + (offset * CGFloat(sin(angle)))
			let   control = NSRect(origin: CGPoint(x: x, y: y), size: CGSize()).insetBy(dx: -radius, dy: -radius)

			result.append(control)
		}

		return result
	}

	private func item(containedIn iRect: CGRect?) -> NSObject? {
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

}
