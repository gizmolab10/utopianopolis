//
//  ZRingView.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/16/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class ZRingView: ZView, ZTooltips {

	struct ZGeometry {
		var one   = CGRect()
		var thick = CGFloat()
	}

	var geometry         = ZGeometry()
	var necklaceObjects  = ZObjectsArray()
	var necklaceDotRects = [Int : CGRect]()
	let necklaceMax 	 = 16

	func anItemIsWithin(_ rect: CGRect?) -> Bool { return itemWithin(rect) != nil }

	override func awakeFromNib() {
		super.awakeFromNib()

		zlayer.backgroundColor = kClearColor.cgColor
	}

	func updateGeometry() {
		let     square = CGSize(width: kRingWidth, height: kRingWidth)
		var       rect = CGRect(origin: CGPoint(), size: square)
		rect.center    = CGPoint(x: kHalfDetailsWidth, y: kHalfDetailsWidth)
		geometry  .one = rect
		geometry.thick = 3.0
	}

	// MARK:- draw
	// MARK:-

	func drawControl(for index: Int) {
		ZControlButton.controls[index].draw(controlRects[index])
	}

	override func draw(_ iDirtyRect: CGRect) {
		super.draw(iDirtyRect)

		if !gIsReadyToShowUI { return }

		let color = gNecklaceDotColor

		color.setStroke()
		kClearColor.setFill()
		necklaceDotRects.removeAll()

		if !gFullRingIsVisible {
			drawControl(for: 1)
		} else {
			let            g = geometry
			let         rect = g.one
			let surroundRect = rect.insetEquallyBy(-6.0)
			let       radius = Double(surroundRect.size.width) / 27.0

			ZBezierPath.drawCircle (in: rect, thickness: g.thick)

			drawNecklaceDots(surrounding: surroundRect, objects: necklaceObjects, radius: radius, color: color, countMax: necklaceMax + 1) { (index, rect) in
				self.necklaceDotRects[index] = rect
			}

			for index in 0 ... (controlRects.count - 1) {
				drawControl(for: index)
			}

			updateTooltips()
		}
	}

	// MARK:- respond
	// MARK:-

	func respondToRingControl(_ item: NSObject) -> Bool {
		if  let    control = item as? ZControlButton {
			return control.respond()
		}

		return false
	}

	func focusOnIdea(_ idea: Zone) {
		gControllers.swapGraphAndEssay(force: .graphMode)
		gFocusRing.focusOn(idea) {
			gControllers.signalFor(idea, regarding: .sRelayout)
		}
	}

	func focusOnEssay(_ note: ZNote) {
		gEssayView?.resetCurrentEssay(note)
		gControllers.swapGraphAndEssay(force: .noteMode)
		gSignal([.sCrumbs, .sRing])
	}

	func respond(to item: NSObject, CONTROL: Bool = false, COMMAND: Bool = false) -> Bool {
		if  CONTROL {
			var removeMe = item

			if  let dual = item as? ZObjectsArray {
				removeMe = gIsNoteMode ? dual[1] : dual[0]
			}

			if  removeFromRings(removeMe) {
				return true
			}
		} else if let idea = item as? Zone {
			if !COMMAND, ((idea != gHere) || gIsNoteMode) {
				focusOnIdea(idea)
			} else if COMMAND, idea.countOfNotes > 0 {
				focusOnEssay(idea.note)
			} else {
				return false
			}

			return true
		} else if let note = item as? ZNote,
			let idea = note.zone {
			if !COMMAND, ((idea != gCurrentEssayZone) || !gIsNoteMode) {
				focusOnEssay(note)
			} else if COMMAND {
				focusOnIdea(idea)
			} else {
				return false
			}

			return true
		}

		return false
	}

	@discardableResult func handleClick(in rect: CGRect?, flags: ZEventFlags = ZEventFlags()) -> Bool {   // false means click was ignored
		if  let item = self.itemWithin(rect) {
			let CONTROL = flags.isControl
			let COMMAND = flags.isCommand

			if (gFullRingIsVisible && respond(to: item, CONTROL: CONTROL, COMMAND: COMMAND)) || respondToRingControl(item) { // single item
				gRedrawGraph()

				return true
			} else if var subitems = item as? ZObjectsArray {	  // array of items
				if  gIsNoteMode ^^ COMMAND {
					subitems = subitems.reversed()
				}

				for subitem in subitems {
					if  respond(to: subitem, CONTROL: CONTROL) {
						gRedrawGraph()

						return true
					}
				}
			}
		}

		return false
	}

	override func mouseDown(with event: ZEvent) {
		let   rect = convert(CGRect(origin: event.locationInWindow, size: CGSize()), from: nil)
		let inRing = handleClick(in: rect, flags: event.modifierFlags)

		if !inRing {
			super.mouseDown(with: event)
		}
	}

	// MARK:- necklace
	// MARK:-

	func addUnique(from ring: ZObjectsArray) {
		for object in ring.reversed() {
			guard let (index, same, dual) = necklaceIndexOf(object) else {
				addToNecklace(object, at: nil)

				continue
			}

			if !dual, !same {
				let  original = necklaceObjects[index]
				let   wasZone = original.isKind(of: Zone.self)
				let    isZone =   object.isKind(of: Zone.self)
				if     isZone != wasZone {
					let array = isZone ? [object, original] : [original, object]

					addToNecklace(array as NSObject, at: index)
				}
			}
		}
	}

	func addToNecklace(_ object: NSObject, at index: Int?) {
		if !necklaceObjects.contains(object) {
			if  index != nil {
				necklaceObjects[index!] = object
			} else {
				necklaceObjects.append(object)
			}

			printDebug(.dRing, "v     add: \(object)")
		}
	}

	func removeFromNecklace(_ index: Int) {
		printDebug(.dRing, "v  remove: \(necklaceObjects[index])")
		necklaceObjects.remove(at: index)
	}

	@discardableResult func removeFromRings(_ item: NSObject, okayToRecurse: Bool = true) -> Bool {
		guard let array = item as? ZObjectsArray else {
			return gFocusRing.removeFromStack(item, okayToRecurse: okayToRecurse) || gEssayRing.removeFromStack(item, okayToRecurse: okayToRecurse) // recursion is okay: can call update necklace within
		}

		var result =           gFocusRing.removeFromStack(array[0], okayToRecurse: okayToRecurse)   // MUST invoke on both rings
		result     = result || gEssayRing.removeFromStack(array[1], okayToRecurse: okayToRecurse)

		return result
	}

	func removeStale() {
		let array = Array(necklaceObjects.reversed())

		for (reverseIndex, object) in array.enumerated() {
			let index = array.count - reverseIndex - 1

			if  necklaceObjects.count <= index {
				continue
			} else if object.isKind(of:  Zone.self), !gFocusRing.ring.contains(object) {
				removeFromNecklace(index)
			} else if object.isKind(of: ZNote.self), !gEssayRing.ring.contains(object) {
				removeFromNecklace(index)
			} else if let dual = object as? ZObjectsArray {
				let     zone = dual[0]
				let     note = dual[1]
				var keepZone = false
				var keepNote = false

				if  gFocusRing.ring.contains(zone) {
					keepZone = true
				}

				if  gEssayRing.ring.contains(note) {
					keepNote = true
				}

				if !keepZone && !keepNote {
					removeFromNecklace(index)
				} else if keepZone && !keepNote {
					addToNecklace(zone, at: index)
				} else if keepNote && !keepZone {
					addToNecklace(note, at: index)
				}
			}
		}
	}

	func removeExtras() {
		while necklaceObjects.count > necklaceMax {
			removeFromRings(necklaceObjects[0], okayToRecurse: false)
			removeFromNecklace(0)
		}
	}

	func updateNecklace(doNotResignal: Bool = false) {
		addUnique(from: gFocusRing.ring)
		addUnique(from: gEssayRing.ring)
		removeStale()
		removeExtras()

		if  doNotResignal {
			setNeedsDisplay()
		} else {
			gSignal([.sRing])
		}
	}

	func necklaceIndexOf(_ item: NSObject) -> (Int, Bool, Bool)? {
		if  let index = necklaceObjects.firstIndex(of: item) {
			return (index, true, false)
		}

		if  let recordName = (item as? ZIdentifiable)?.recordName() {
			for (index, object) in necklaceObjects.enumerated() {
				if  let subObjects = object as? ZObjectsArray {
					for subObject in subObjects {
						if  let subName = (subObject as? ZIdentifiable)?.recordName(),
							subName == recordName {
							return (index, true, true)
						}
					}
				} else if let identifiable = object as? ZIdentifiable,
					identifiable.recordName() == recordName {
					return (index, false, false)
				}
			}
		}

		return nil
	}

	// MARK:- controls
	// MARK:-

	var controlRects : [CGRect] {
		let   rect = geometry.one
		let radius = rect.width / 4.5
		let offset = rect.width / 3.7
		let center = rect.center
		var result = [CGRect]()

		for angle in [-Double.pi, 0.0] {
			let  x = center.x + (offset * CGFloat(cos(angle)))
			let  y = center.y + (offset * CGFloat(sin(angle)))
			let  r = CGRect(origin: CGPoint(x: x, y: y), size: CGSize.zero).insetEquallyBy(-radius)

			result.append(r)
		}

		return result
	}

	private func itemWithin(_ iRect: CGRect?) -> NSObject? {
		if  let     rect = iRect {
			let  objects = necklaceObjects 				// expensive computation: do once
			let    count = objects.count
			let controls = ZControlButton.controls

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
				return ZControlButton.tooltips
			}
		}

		return nil
	}

}
