//
//  ZEssayView+Grab.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/23/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

typealias ZEssayGrabDotArray = [ZEssayGrabDot]

struct ZEssayGrabDot {
	var      dotNote : ZNote?
	var    noteRange : NSRange?
	var noteLineRect : CGRect?
	var noteDragRect = CGRect.zero
	var noteTextRect = CGRect.zero
	var     dotColor = kWhiteColor
}

extension ZEssayView {

	var grabbedZones       : ZoneArray { return grabbedNotes.map { $0.zone! } }
	var hasGrabbedNote     : Bool      { return grabbedNotes.count != 0 }
	var firstIsGrabbed     : Bool      { return hasGrabbedNote && firstGrabbedZone == firstNote?.zone }
	var firstGrabbedNote   : ZNote?    { return hasGrabbedNote ? grabbedNotes[0] : nil }
	var firstGrabbedZone   : Zone?     { return firstGrabbedNote?.zone }
	var firstNote          : ZNote?    { return (grabDots.count == 0) ? nil : grabDots[0].dotNote }

	func grabNote(_ note: ZNote) {
		grabbedNotes.appendUnique(item: note.firstNote)
	}

	func ungrabNote(_ note: ZNote) -> Bool {
		if  let index = grabbedNotes.firstIndex(of: note.firstNote) {
			grabbedNotes.remove(at: index)

			return true
		}

		return false
	}

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
			grabNextNote(down: arrow == .down, ungrab: !flags.hasShift)
			scrollToGrabbed()
			gDispatchSignals([.sDetails])
		}
	}

	func grabbedIndex(goingDown: Bool) -> Int? {
		let dots = goingDown ? grabDots : grabDots.reversed()
		let  max = dots.count - 1

		for (index, dot) in dots.enumerated() {
			if  let zone = dot.dotNote?.zone,
				grabbedZones.contains(zone) {
				return goingDown ? index : max - index
			}
		}

		return nil
	}

	var lastGrabbedDot : ZEssayGrabDot? {
		var    grabbed : ZEssayGrabDot?

		for dot in grabDots {
			if  let zone = dot.dotNote?.zone,
				grabbedZones.contains(zone) {
				grabbed  = dot
			}
		}

		return grabbed
	}

	var grabDots : ZEssayGrabDotArray {
		var dots = ZEssayGrabDotArray()

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
					let        dot = ZEssayGrabDot(dotNote: note, noteRange: noteRange, noteLineRect: lineRect, noteDragRect: dragRect, noteTextRect: noteRect, dotColor: color)

					dots.append(dot)
				}
			}
		}

		return dots
	}

	func dragDotHit(at rect: CGRect) -> ZEssayGrabDot? {
		for dot in grabDots {
			if  dot.noteDragRect.intersects(rect) {
				return dot
			}
		}

		return nil
	}

	func swapGrabbedWithParent() {
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

	func grabSelected() {
		let  hadNoGrabs = !hasGrabbedNote

		ungrabAll()

		if  hadNoGrabs,
			gCurrentEssay?.childrenNotes.count ?? 0 > 1 {     // ignore if does not have multiple children

			for note in selectedNotes {
				grabNote(note)
			}

			scrollToGrabbed()
			gDispatchSignals([.sDetails])
		}

		setNeedsDisplay()
	}

	func grabNextNote(down: Bool, ungrab: Bool) {
		let      dots = grabDots
		if  let index = grabbedIndex(goingDown: down),
			let   dot = dots.next(goingDown: down, from: index),
			var  note = dot.dotNote {

			if  ungrab {
				ungrabAll()
			}

			grabNote(note)
			scrollToGrabbed()
			gDispatchSignals([.sDetails])
		}
	}

	func scrollToGrabbed() {
		if  let range = lastGrabbedDot?.noteRange {
			scrollRangeToVisible(range)
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
				grabNote(note)
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
		gDispatchSignals([.spCrumbs, .sDetails])
	}

	// MARK: - draw grab dots
	// MARK: -

	func drawNoteDecorations() {
		resetVisibilities()

		let dots = grabDots
		if  dots.count > 0 {
			for (index, dot) in dots.enumerated() {
				if  let     note = dot.dotNote?.firstNote,
					let     zone = note.zone {
					let  grabbed = grabbedZones.contains(zone)
					let selected = note.noteRange.inclusiveIntersection(selectedRange) != nil
					let   filled = selected && !hasGrabbedNote
					let    color = dot.dotColor

					drawVisibilityIcons(for: index, y: dot.noteDragRect.midY, isANote: !zone.hasChildNotes)  // draw visibility icons

					if  gEssayTitleMode == .sFull {
						dot.noteDragRect.drawColoredOval(color, thickness: 2.0, filled: filled || grabbed)   // draw drag dot

						if  let lineRect = dot.noteLineRect {
							drawColoredRect(lineRect, color, thickness: 0.5)             // draw indent line in front of drag dot
						}

						if  grabbed {
							drawColoredRect(dot.noteTextRect, color)                         // draw box around entire note
						}
					}
				}
			}
		} else if let note = gCurrentEssay, visibilities.count > 0,
				  let zone = note.zone,
				  let    c = textContainer,
				  let    l = layoutManager {
			let       rect = l.boundingRect(forGlyphRange: note.noteRange, in: c)

			drawVisibilityIcons(for: 0, y: rect.minY + 33.0, isANote: !zone.hasChildNotes)                              // draw visibility icons
		}
	}

}
