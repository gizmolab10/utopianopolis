//
//  ZEssayView+Grab.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/23/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

typealias ZEssayDragDotArray = [ZEssayDragDot]

struct ZEssayDragDot {
	var     color = kWhiteColor
	var  dragRect = CGRect.zero
	var  textRect = CGRect.zero
	var  lineRect : CGRect?
	var noteRange : NSRange?
	var      note : ZNote?
}

extension ZEssayView {

	var grabbedZones       : ZoneArray { return grabbedNotes.map { $0.zone! } }
	var firstGrabbedNote   : ZNote?    { return hasGrabbedNote ? grabbedNotes[0] : nil }
	var firstGrabbedZone   : Zone?     { return firstGrabbedNote?.zone }
	var firstNote          : ZNote?    { return (dragDots.count == 0) ? nil : dragDots[0].note }
	var hasGrabbedNote     : Bool      { return grabbedNotes.count != 0 }
	var firstIsGrabbed     : Bool      { return hasGrabbedNote && firstGrabbedZone == firstNote?.zone }

	func handleGrabbed(_ arrow: ZArrowKey, flags: ZEventFlags) {

		// SHIFT single note expand to essay and vice-versa

		let indents = relativeLevelOfFirstGrabbed

		if  flags.hasOption {
			if (arrow == .left && indents > 1) || ([.up, .down, .right].contains(arrow) && indents > 0) {
				save()

				gMapEditor.handleArrow(arrow, flags: flags) { [self] in
					resetTextAndGrabs()
				}
			}
		} else if flags.hasShift {
			if [.left, .right].contains(arrow) {
				// conceal reveal subnotes of grabbed (NEEDS new ZEssay code)
			}
		} else if arrow == .left {
			if  indents == 0 {
				done()
			} else {
				swapBetweenNoteAndEssay()
			}
		} else if [.up, .down].contains(arrow) {
			grabNextNote(up: arrow == .up, ungrab: !flags.hasShift)
			scrollToGrabbed()
			gSignal([.sDetails])
		}
	}

	func grabbedIndex(goingUp: Bool) -> Int? {
		let dots = goingUp ? dragDots : dragDots.reversed()
		let  max = dots.count - 1

		for (index, dot) in dots.enumerated() {
			if  let zone = dot.note?.zone,
				grabbedZones.contains(zone) {
				return goingUp ? index : max - index
			}
		}

		return nil
	}

	var lastGrabbedDot : ZEssayDragDot? {
		var    grabbed : ZEssayDragDot?

		for dot in dragDots {
			if  let zone = dot.note?.zone,
				grabbedZones.contains(zone) {
				grabbed  = dot
			}
		}

		return grabbed
	}

	var dragDots : ZEssayDragDotArray {
		var dots = ZEssayDragDotArray()

		if  let essay = gCurrentEssay, !essay.isNote,
			let  zone = essay.zone,
			let     l = layoutManager,
			let     c = textContainer {
			let zones = zone.zonesWithVisibleNotes
			let level = zone.level

			essay.updateNoteOffsets()

			for (index, zone) in zones.enumerated() {
				if  var note       = zone.note {
					if  index     == 0 {
						note       = essay
					}

					let dragHeight = 15.0
					let  dragWidth = 11.75
					let      inset = CGFloat(2.0)
					let     offset = index == 0 ? 0 : 1               // first note has an altered offset ... thus, an altered range
					let     indent = zone.level - level
					let     noLine = indent == 0
					let      color = zone.color ?? kDefaultIdeaColor
					let  noteRange = note.noteRange.offsetBy(offset)
					let   noteRect = l.boundingRect(forGlyphRange: noteRange, in: c).offsetBy(dx: 18.0, dy: margin + inset + 1.0).expandedEquallyBy(inset)
					let lineOrigin = noteRect.origin.offsetBy(CGPoint(x: 3.0, y: dragHeight - 2.0))
					let  lineWidth = dragWidth * Double(indent)
					let   lineSize = CGSize(width: lineWidth, height: 0.5)
					let   lineRect = noLine ? nil : CGRect(origin: lineOrigin, size: lineSize)
					let dragOrigin = lineOrigin.offsetBy(CGPoint(x: lineWidth, y: dragHeight / -2.0))
					let   dragSize = CGSize(width: dragWidth, height: dragHeight)
					let   dragRect = CGRect(origin: dragOrigin, size: dragSize)
					let        dot = ZEssayDragDot(color: color, dragRect: dragRect, textRect: noteRect, lineRect: lineRect, noteRange: noteRange, note: note)

					dots.append(dot)
				}
			}
		}

		return dots
	}

	func dragDotHit(at rect: CGRect) -> ZEssayDragDot? {
		for dot in dragDots {
			if  dot.dragRect.intersects(rect) {
				return dot
			}
		}

		return nil
	}

	func grabSelected() {
		let  hadNoGrabs = !hasGrabbedNote

		ungrabAll()

		if  hadNoGrabs,
			gCurrentEssay?.children.count ?? 0 > 1 {     // ignore if does not have multiple children

			for note in selectedNotes {
				grabbedNotes.appendUnique(item: note)
			}

			scrollToGrabbed()
			gSignal([.sDetails])
		}

		setNeedsDisplay()
	}

	func grabNextNote(up: Bool, ungrab: Bool) {
		let      dots = dragDots
		if  let index = grabbedIndex(goingUp: up),
			let   dot = dots.next(increasing: up, from: index),
			let  note = dot.note {

			if  ungrab {
				ungrabAll()
			}

			grabbedNotes.append(note)
			scrollToGrabbed()
			gSignal([.sDetails])
		}
	}

	func scrollToGrabbed() {
		if  let range = lastGrabbedDot?.noteRange {
			scrollRangeToVisible(range)
		}
	}

	func swapWithParent() {
		if !firstIsGrabbed,
		   let note = firstGrabbedNote,
		   let zone = note.zone {
			save()
			gCurrentEssayZone?.clearAllNoteMaybes()            // discard current essay text and all child note's text
			ungrabAll()

			gNeedsRecount = true
			let    parent = zone.parentZone                  // get the parent before we swap
			let     reset = parent == firstNote?.zone        // check if current esssay should change

			gDisablePush {
				zone.swapWithParent { [self] in
					if  reset {
						gCurrentEssay = gCreateEssay(zone)
					}

					resetTextAndGrabs(grab: parent)
				}
			}
		}
	}

	func setGrabbedZoneAsCurrentEssay() {
		if  let      note = firstGrabbedNote {
			gCurrentEssay = note

			ungrabAll()
			resetTextAndGrabs()
		}
	}

	@discardableResult func deleteGrabbedOrSelected() -> Bool {
		save() // capture all the current changes before deleting

		if  hasGrabbedNote {
			for zone in grabbedZones {
				zone.deleteNote()
			}

			ungrabAll()
			resetTextAndGrabs()

			return true
		}

		if  let  zone = selectedNotes.last?.zone,
			let count = gCurrentEssay?.zone?.zonesWithNotes.count, count > 1 {
			zone.deleteNote()
			resetTextAndGrabs()

			return true
		}

		return false
	}

	func ungrabAll() { grabbedNotes.removeAll() }

	func regrab(_ ungrabbed: ZoneArray) {
		for zone in ungrabbed {                       // re-grab notes for set aside zones
			if  let note = zone.note {                // note may not be same
				grabbedNotes.appendUnique(item: note)
			}
		}
	}

	func willRegrab(_ grab: Zone? = nil) -> ZoneArray {
		var           grabbed = ZoneArray()

		grabbed.append(contentsOf: grabbedZones)      // copy current grab's zones aside
		ungrabAll()

		if  let          zone = grab {
			grabbed           = [zone]

			if  zone         == gCurrentEssay?.zone,
				let     first = firstGrabbedZone {
				gCurrentEssay = gCreateEssay(first)
			}
		}

		return grabbed
	}

	func resetTextAndGrabs(grab: Zone? = nil) {
		let     grabbed = willRegrab(grab)              // includes logic for optional grab parameter
		essayRecordName = nil                           // so shouldOverwrite will return true

		gCurrentEssayZone?.clearAllNoteMaybes()         // discard current essay text and all child note's text
		updateTextStorage()                             // assume text has been altered: re-assemble it
		regrab(grabbed)
		scrollToGrabbed()
		gSignal([.spCrumbs, .sDetails])
	}

}
