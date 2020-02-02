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

class ZRingView: ZView {

	struct ZGeometry {
		var one   = CGRect()
		var thick = CGFloat()
	}

	var geometry         = ZGeometry()
	var necklaceDotRects = [Int : CGRect]()

	override func awakeFromNib() {
		super.awakeFromNib()

		zlayer.backgroundColor = kClearColor.cgColor
	}

	func update() {
		var      square = bounds.squareCentered
		let squareInset = square.width / 2.85 - 20.0
		let       inset = squareInset  / 2.85
		square          = square.insetBy(dx: squareInset, dy: squareInset)
		let         one = square.insetBy(dx: inset,       dy: inset)
		let     xOffset = bounds.maxX - square.maxX - 35.0 +  inset / 1.8
		let     yOffset = bounds.maxY - square.maxY - 35.0 +  inset / 1.8
		geometry   .one = one  .offsetBy(dx: xOffset, dy: yOffset)
		geometry .thick = square.height / 30.0
	}

	// MARK:- draw
	// MARK:-

	func drawControl(for index: Int) {
		ZRingControl.controls[index].draw(controlRects[index])
	}

	override func draw(_ iDirtyRect: CGRect) {
		super.draw(iDirtyRect)

		let color = gDirectionIndicatorColor

		color.setStroke()
		kClearColor.setFill()

		if !gFullRingIsVisible {
			drawControl(for: 1)
		} else {
			let            g = geometry
			let         rect = g.one
			let surroundRect = rect.insetBy(dx: -6.0, dy: -6.0)
			let       radius = Double(surroundRect.size.width) / 27.0

			ZBezierPath.drawCircle (in: rect, thickness: g.thick)

			drawTinyDots(surrounding: surroundRect, objects: necklaceObjects, radius: radius, color: color, startQuadrant: -1.0) { (index, rect) in
				self.necklaceDotRects[index] = rect
			}

			for index in 0 ... (controlRects.count - 1) {
				drawControl(for: index)
			}

			addToolTips(for: self)
		}
	}

	// MARK:- respond
	// MARK:-

	func respondToRingControl(_ item: NSObject) -> Bool {
		if  let control = item as? ZRingControl {
			control.response()

			return true
		}

		return false
	}

	func focusOnIdea(_ item: NSObject) -> Bool {
		if  let idea = item as? Zone {
			gControllers.swapGraphAndEssay(for: .graphMode)
			gFocusRing.focusOn(idea) {
				printDebug(.ring, idea.zoneName ?? "unknown zone")
				gControllers.signalFor(idea, regarding: .eRelayout)
			}

			return true
		}

		return false
	}

	func focusOnEssay(_ item: NSObject) -> Bool {
		if  let essay = item as? ZParagraph {
			gControllers.swapGraphAndEssay(for: .essayMode)
			gEssayView?.resetCurrentEssay(essay)

			printDebug(.ring, essay.zone?.zoneName ?? "unknown essay")

			return true
		}

		return false
	}

	@discardableResult func respondToClick(in rect: CGRect?, _ COMMAND: Bool? = nil) -> Bool {
		func respond(to item: NSObject) -> Bool {
			return focusOnIdea(item) || focusOnEssay(item)
		}

		if  let item = self.item(containedIn: rect) {
			if  respond(to: item) || respondToRingControl(item) {
				setNeedsDisplay()

				return true
			} else if var subitems = item as? ZObjectsArray {
				if  (gWorkMode == .essayMode) ^^ (COMMAND ?? false) {
					subitems = subitems.reversed()
				}

				for subitem in subitems {
					if  respond(to: subitem) {
						setNeedsDisplay()

						return true
					}
				}
			}
		}

		return false
	}

	override func mouseDown(with event: ZEvent) {
		let    rect = CGRect(origin: event.locationInWindow, size: CGSize())
		let COMMAND = event.modifierFlags.isCommand
		let  inRing = respondToClick(in: rect, COMMAND)

		if !inRing {
			super.mouseDown(with: event)
		}
	}

	// MARK:- necklace and controls
	// MARK:-

	var necklaceObjects : ZObjectsArray {
		var results = ZObjectsArray()

		func copyObjects(from ring: ZObjectsArray) {
			for object in ring {
				if  object.isKind(of: Zone.self) {
					results.append(object)
				} else if let  essay = object as? ZParagraph,
					let idea = essay.zone {

					if  let index = results.firstIndex(of: idea) {
						results[index] = [idea, essay] as NSObject
					} else {
						results.append(object)
					}
				}
			}
		}

		copyObjects(from: gFocusRing.ring)
		copyObjects(from: gEssayRing.ring)

		return results
	}

	var controlRects : [CGRect] {
		let   rect = geometry.one
		let radius = rect.width / 4.5
		let offset = rect.width / 3.7
		let center = rect.center
		var result = [CGRect]()

		for index in 0 ... 2 {
			let increment = 2.0 * .pi / 3.2 	// 1/3.2 of circle (2 pi)
			let     angle = (1.8 - Double(index)) * increment
			let         x = center.x + (offset * CGFloat(cos(angle)))
			let         y = center.y + (offset * CGFloat(sin(angle)))
			let   control = NSRect(origin: CGPoint(x: x, y: y), size: CGSize()).insetBy(dx: -radius, dy: -radius)

			result.append(control)
		}

		return result
	}

	private func item(containedIn iRect: CGRect?) -> NSObject? {
		if  let     rect = iRect {
			let  objects = necklaceObjects 				// expensive computation: do once
			let    count = objects.count
			let controls = ZRingControl.controls

			for (index, dotRect) in necklaceDotRects {
				if  index < count, 						// avoid crash
					rect.intersects(dotRect) {
					return objects[index]
				}
			}

			for (index, controlRect) in controlRects.enumerated() {
				if  rect.intersectsOval(within: controlRect) {
					return controls[index]
				}
			}
		}

		return nil
	}

	func addToolTips(for     iToolView: ZView?) {
		guard let toolView = iToolView else { return }
		let       controls = ZRingControl.controls
		let        objects = necklaceObjects 				// expensive computation: do once
		let          count = objects.count

		toolView.removeAllToolTips()

		for (index, tinyRect) in necklaceDotRects {
			if  index < count { 							// avoid crash
				var      owner = objects[index]
				let       rect = self.convert(tinyRect, to: toolView)

				if  let owners = owner as? [NSObject] {
					owner      = owners[0]
				}

				toolView.addToolTip(rect, owner: owner, userData: nil)
			}
		}

		for (index, controlRect) in controlRects.enumerated() {
			let  rect = self.convert(controlRect, to: toolView)
			let owner = controls[index]

			toolView.addToolTip(rect, owner: owner, userData: nil)
		}
	}
}
