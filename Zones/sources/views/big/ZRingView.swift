//
//  ZRingView.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 2/16/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

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
	var necklaceObjects  = ZObjectsArray()
	var necklaceDotRects = [Int : CGRect]()
	let necklaceMax 	 = 16

	func itemInRect(_ rect: CGRect?) -> Bool { return item(containedIn: rect) != nil }

	override func awakeFromNib() {
		super.awakeFromNib()

		zlayer.backgroundColor = kClearColor.cgColor
	}

	func update() {
		let     square = CGSize(width: 130.0, height: 130.0)
		let     origin = CGPoint(x: bounds.maxX - square.width - 50.0, y: bounds.maxY - square.height - 90.0)
		geometry  .one = CGRect(origin: origin, size: square)
		geometry.thick = square.height / 40.0
	}

	// MARK:- draw
	// MARK:-

	func drawControl(for index: Int) {
		ZRingControl.controls[index].draw(controlRects[index])
	}

	override func draw(_ iDirtyRect: CGRect) {
		super.draw(iDirtyRect)

		if !gHasFinishedStartup { return }

		let color = gNecklaceDotColor

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

			drawTinyDots(surrounding: surroundRect, objects: necklaceObjects, radius: radius, color: color, offsetAngle: (.pi / -2.0) + 0.005, countMax: necklaceMax + 1) { (index, rect) in
				self.necklaceDotRects[index] = rect
			}

			for index in 0 ... (controlRects.count - 1) {
				drawControl(for: index)
			}

			addToolTips()
		}
	}

	// MARK:- respond
	// MARK:-

	func respondToRingControl(_ item: NSObject) -> Bool {
		if  let    control = item as? ZRingControl {
			return control.respond()
		}

		return false
	}

	func focusOnIdea(_ idea: Zone) {
		gControllers.swapGraphAndEssay(force: .graphMode)
		gFocusRing.focusOn(idea) {
			gControllers.signalFor(idea, regarding: .eRelayout)
		}
	}

	func focusOnEssay(_ note: ZNote) {
		gControllers.swapGraphAndEssay(force: .noteMode)
		gEssayView?.resetCurrentEssay(note)
		signalMultiple([.eCrumbs, .eRing])
	}

	func respond(to item: NSObject, CONTROL: Bool = false, COMMAND: Bool = false) -> Bool {
		if  CONTROL {
			if  removeFromRings(item) {
				return true
			}
		} else if let idea = item as? Zone {
			if !COMMAND, ((idea != gHere) || gIsNoteMode) {
				focusOnIdea(idea)
			} else if COMMAND, idea.countOfNotes > 0 {
				focusOnEssay(idea.freshEssay)
			} else {
				return false
			}

			return true
		} else if let note = item as? ZNote {
			if !COMMAND, ((note != gCurrentEssay) || !gIsNoteMode) {
				focusOnEssay(note)
			} else if COMMAND, let idea = note.zone {
				focusOnIdea(idea)
			} else {
				return false
			}

			return true
		}

		return false
	}

	@discardableResult func respondToClick(in rect: CGRect?, CONTROL: Bool = false, COMMAND: Bool = false) -> Bool {   // false means click was ignored
		if  let item = self.item(containedIn: rect) {
			if (gFullRingIsVisible && respond(to: item, CONTROL: CONTROL, COMMAND: COMMAND)) || respondToRingControl(item) { // single item
				setNeedsDisplay()

				return true
			} else if var subitems = item as? ZObjectsArray {	  // array of items
				if  gIsNoteMode ^^ COMMAND {
					subitems = subitems.reversed()
				}

				for subitem in subitems {
					if  respond(to: subitem, CONTROL: CONTROL) {
						setNeedsDisplay()

						return true
					}
				}
			}
		} else if gIsNoteMode, let v = gEssayView, let r = rect, !v.frame.contains(r) {
			v.save()
			gControllers.swapGraphAndEssay(force: .graphMode)
			signalRegarding(.eRelayout)

			return true
		}

		return false
	}

	override func mouseDown(with event: ZEvent) {
		let    rect = CGRect(origin: event.locationInWindow, size: CGSize())
		let CONTROL = event.modifierFlags.isControl
		let COMMAND = event.modifierFlags.isCommand
		let  inRing = respondToClick(in: rect, CONTROL: CONTROL, COMMAND: COMMAND)

		if !inRing {
			super.mouseDown(with: event)
		}
	}

	// MARK:- necklace and controls
	// MARK:-

	func updateNecklace() {
		necklaceObjects.removeAll()

		func copyObjects(from ring: ZObjectsArray) {
			for object in ring.reversed() {
				if  object.isKind(of: Zone.self) {
					necklaceObjects.append(object)
				} else if let  essay = object as? ZNote,
					let idea = essay.zone {

					if  let index = necklaceObjects.firstIndex(of: idea) {
						necklaceObjects[index] = [idea, essay] as NSObject
					} else {
						necklaceObjects.append(object)
					}
				}
			}
		}

		copyObjects(from: gFocusRing.ring)
		copyObjects(from: gEssayRing.ring)

		while necklaceObjects.count > necklaceMax {
			removeFromRings(necklaceObjects[0])
			necklaceObjects.remove(at: 0)
		}

		signalRegarding(.eRing)
	}

	@discardableResult func removeFromRings(_ item: NSObject) -> Bool {
		if  let array = item as? ZObjectsArray {
			return gFocusRing.removeFromStack(array[0]) || gEssayRing.removeFromStack(array[1])
		} else {
			return gFocusRing.removeFromStack(item)     || gEssayRing.removeFromStack(item)
		}
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

			for (index, controlRect) in controlRects.enumerated() {
				if  rect.intersectsOval(within: controlRect) {
					let control = controls[index]

					if  control.shape(in: controlRect, contains: rect.origin) {
						return control
					}
				}
			}

			for (index, dotRect) in necklaceDotRects {
				if  index < count, 						// avoid crash
					rect.intersects(dotRect) {
					return objects[index]
				}
			}

			if  rect.intersectsOval(within: geometry.one) {
				return ZRingControl.tooltips
			}
		}

		return nil
	}

	@discardableResult override func addToolTip(_ rect: NSRect, owner: Any, userData data: UnsafeMutableRawPointer?) -> NSView.ToolTipTag {
		if !gToolTipsAlwaysVisible {
			return super.addToolTip(rect, owner: owner, userData: data)
		} else if  let tool = owner as? ZToolable,
			let        name = tool.toolName() {
			var  attributes = [NSAttributedString.Key : Any]()
			let        font = ZFont.systemFont(ofSize: gFontSize * kFavoritesReduction * kFavoritesReduction)
			var    nameRect = name.rectWithFont(font, options: .usesFontLeading).insetBy(dx: -10.0, dy: 0.0)
			nameRect.center = rect.offsetBy(dx: 10.0, dy: -20.0).center

			if  let   color = tool.toolColor() {
				attributes[.foregroundColor] = color
			}

			name.draw(in: nameRect, withAttributes: attributes)
		}

		return 0
	}

	func addToolTips() {
		let       controls = ZRingControl.controls
		let        objects = necklaceObjects 				// expensive computation: do once
		let          count = objects.count

		removeAllToolTips()

		for (index, tinyRect) in necklaceDotRects {
			if  index < count { 							// avoid crash
				var      owner = objects[index]
				let       rect = self.convert(tinyRect, to: self)

				if  let owners = owner as? [NSObject] {
					owner      = owners[0]
				}

				addToolTip(rect, owner: owner, userData: nil)
			}
		}

		for (index, controlRect) in controlRects.enumerated() {
			let  rect = self.convert(controlRect, to: self).offsetBy(dx: 0.0, dy: -5.0)
			let owner = controls[index]

			addToolTip(rect, owner: owner, userData: nil)
		}
	}
}
