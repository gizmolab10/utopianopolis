//
//  ZEssayView+GrabDots.swift
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
	var noteTextRect = CGRect.zero
	var  dotGrabRect = CGRect.zero
	var     dotColor = kWhiteColor
}

extension ZEssayView {

	var grabbedZones       : ZoneArray { return grabbedNotes.map { $0.zone! } }
	var hasGrabbedNote     : Bool      { return grabbedNotes.count != 0 }
	var firstIsGrabbed     : Bool      { return hasGrabbedNote && firstGrabbedZone == firstNote?.zone }
	var firstGrabbedNote   : ZNote?    { return hasGrabbedNote ? grabbedNotes[0] : nil }
	var firstGrabbedZone   : Zone?     { return firstGrabbedNote?.zone }
	var firstNote          : ZNote?    { return (grabDots.count == 0) ? nil : grabDots[0].dotNote }

	var selectedNotes : ZNoteArray {
		guard let essay = gCurrentEssay else {
			return ZNoteArray() // empty because current essay is nil
		}

		if !essay.hasProgenyNotes {
			return [essay]
		}

		essay.updateNoteOffsets()

		return essay.progenyNotes.filter { selectedRange.intersects($0.noteRange.extendedBy(1)) }
	}

	var lastGrabbedDot : ZEssayGrabDot? {
		var    grabbed : ZEssayGrabDot?

		for grabDot in grabDots {
			if  let zone = grabDot.dotNote?.zone,
				grabbedZones.contains(zone) {
				grabbed  = grabDot
			}
		}

		return grabbed
	}

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
				writeViewToTraits()

				gMapEditor.handleArrowInMap(arrow, flags: flags) { [self] in
					resetTextAndGrabs()
				}
			}
		} else if flags.hasShift {
			if [.left, .right].contains(arrow) {
				// conceal reveal subnotes of grabbed (NEEDS new ZEssay code)
			}
		} else if arrow == .left {
			if  indents == 0 {
				writeTraitsAndExit()
			} else {
				swapNoteAndEssay()
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

	func updateGrabDots() {
		grabDots.removeAll()

		if  let essay = gCurrentEssay, essay.hasProgenyNotes,
			let  zone = essay.zone,
			let     l = layoutManager,
			let     c = textContainer {
			let notes = essay.progenyNotes
			let level = zone.level

			essay.updateNoteOffsets()

			for (index, note) in notes.enumerated() {
				let grabHeight = 15.0
				let  grabWidth = 11.75
				let      inset = CGFloat(2.0)
				let     offset = index == 0 ? 0 : 1               // first note has an altered offset ... thus, an altered range
				let     indent = (note.zone?.level ?? level) - level
				let     noLine = indent == 0
				let      color = zone.color ?? kDefaultIdeaColor
				let  noteRange = note.noteRange.offsetBy(offset)
				let   noteRect = l.boundingRect(forGlyphRange: noteRange, in: c).offsetBy(dx: 18.0, dy: margin + inset + 1.0).expandedEquallyBy(inset)
				let lineOrigin = noteRect.origin.offsetBy(CGPoint(x: 3.0, y: grabHeight - 2.0))
				let  lineWidth = grabWidth * Double(indent)
				let   lineSize = CGSize(width: lineWidth, height: 0.5)
				let   lineRect = noLine ? nil : CGRect(origin: lineOrigin, size: lineSize)
				let grabOrigin = lineOrigin.offsetBy(CGPoint(x: lineWidth, y: grabHeight / -2.0))
				let   grabSize = CGSize(width: grabWidth, height: grabHeight)
				let   grabRect = CGRect(origin: grabOrigin, size: grabSize)
				let        dot = ZEssayGrabDot(dotNote: note, noteRange: noteRange, noteLineRect: lineRect, noteTextRect: noteRect, dotGrabRect: grabRect, dotColor: color)

				grabDots.append(dot)
			}
		}
	}

	func hitTestForGrabDot(at rect: CGRect) -> ZEssayGrabDot? {
		for dot in grabDots {
			if  dot.dotGrabRect.intersects(rect) {
				return dot
			}
		}

		return nil
	}

	func swapGrabbedWithParent() {
		if !firstIsGrabbed,
		   let note = firstGrabbedNote,
		   let zone = note.zone {
			writeViewToTraits()
			gCurrentEssayZone?.clearAllNoteMaybes()            // discard current essay text and all child note's text
			ungrabAll()

			gNeedsRecount = true
			let    parent = zone.parentZone                  // get the parent before we swap
			let     reset = parent == firstNote?.zone        // check if current esssay should change

			gDisablePush {
				zone.swapWithParent { [self] in
					if  reset {
						gCurrentEssay = ZEssay(zone)
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
			gCurrentEssay?.hasProgenyNotes ?? false {     // ignore if does not have multiple children

			for note in selectedNotes {
				grabNote(note)
			}

			scrollToGrabbed()
			gDispatchSignals([.sDetails])
		}

		setNeedsDisplay()
	}

	func grabNextNote(down: Bool, ungrab: Bool) {
		if  let index = grabbedIndex(goingDown: down),
			let   dot = grabDots.next(goingDown: down, from: index),
			let  note = dot.dotNote {

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
		writeViewToTraits() // capture all the current changes before deleting

		if  hasGrabbedNote {
			for zone in grabbedZones {
				zone.deleteNote()
			}

			ungrabAll()
			resetTextAndGrabs()

			return true
		}

		if  let  zone = selectedNotes.last?.zone,
			let count = gCurrentEssay?.zone?.zoneProgenyWithNotes.count, count > 1 {
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
				gCurrentEssay = ZEssay(first)
			}
		}

		return grabbed
	}

	func resetTextAndGrabs(grab: Zone? = nil) {
		let     grabbed = willRegrab(grab)              // includes logic for optional grab parameter
		essayRecordName = nil                           // so shouldOverwrite will return true

		gCurrentEssayZone?.clearAllNoteMaybes()         // discard current essay text and all child note's text
		readTraitsIntoView()                             // assume text has been altered: re-assemble it
		regrab(grabbed)
		scrollToGrabbed()
		gDispatchSignals([.spCrumbs, .sDetails])
	}

	// MARK: - draw grab dots
	// MARK: -

	func drawNoteDecorations() {
		resetVisibilities()

		if  grabDots.count > 0 {
			for (index, dot) in grabDots.enumerated() {
				if  let     note = dot.dotNote?.firstNote,     // first note has note's noteRange, not essay's
					let     zone = note.zone {
					let  grabbed = grabbedNotes.contains(note)
					let selected = note.noteRange.inclusiveIntersection(selectedRange) != nil
					let   filled = selected && !hasGrabbedNote
					let    color = dot.dotColor

					if  gEssayTitleMode == .sFull {
						dot.dotGrabRect.drawColoredOval(color, thickness: 2.0, filled: filled || grabbed)   // draw grab dot

						if  let lineRect = dot.noteLineRect {
							drawColoredRect(lineRect, color, thickness: 0.5)             // draw indent line in front of grab dot
						}

						if  grabbed {
							drawColoredRect(dot.noteTextRect, color)                         // draw box around entire note
						}
					}

					drawVisibilityIcons(for: index, y: dot.dotGrabRect.midY, isANote: !zone.hasChildNotes)  // draw visibility icons
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
