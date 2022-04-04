//
//  ZNote.swift
//  Seriously
//
//  Created by Jonathan Sand on 12/27/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

enum ZAlterationType: Int {
	case eDelete
	case eAlter
	case eLock
	case eExit
}

class ZNote: NSObject, ZIdentifiable, ZToolable {
	var          essayLength = 0
	var          indentCount = 0
	var           noteOffset = 0
	var           autoDelete = false		// true means delete this note on exit from essay mode
	var             children = [ZNote]()
	var           titleRange = NSRange()
	var            textRange = NSRange()
	var            noteRange : NSRange   { return NSRange(location: noteOffset, length: textRange.upperBound) }
	var        lastTextRange : NSRange?  { return textRange }
	var        noteTextRange : NSRange   { return textRange.offsetBy(noteOffset) }
	var       maybeNoteTrait : ZTrait?   { return zone?.maybeTraitFor(.tNote) }
	var            noteTrait : ZTrait?   { return zone?     .traitFor(.tNote) }
	var           essayTrait : ZTrait?   { return zone?     .traitFor(.tEssay) }
	var           recordName : String?   { return zone?.recordName }
	var                 kind : String    { return "note" }
	var               prefix : String    { return titleIndent }
	var               suffix : String    { return kTab }
	override var description : String    { return zone?.unwrappedName ?? kEmptyIdea }
	var          titleIndent : String    { return kNoteIndentSpacer * indentCount }
	var          titleOffset : Int       { return titleIndent.length }
	var      fullTitleOffset : Int       { return noteOffset + titleRange.location - titleOffset }
	var    lastTextIsDefault : Bool      { return maybeNoteTrait?.text == kNoteDefault }
	var               isNote : Bool      { return isMember(of: ZNote.self) }
	var    	            zone : Zone?

	func setupChildren() {}
	func updateNoteOffsets() {}
	func noteIn(_ range: NSRange) -> ZNote { return self }
	func saveAsEssay(_ attributedString: NSAttributedString?) { saveAsNote(attributedString) }
	func updateFontSize(_ increment: Bool) -> Bool { return updateTraitFontSize(increment) }
	func updateTraitFontSize(_ increment: Bool) -> Bool { return noteTrait?.updateEssayFontSize(increment) ?? false }

	init(zones: ZoneArray) {}

	init(_ zone: Zone?) {
		super.init()

		autoDelete = true
		self.zone  = zone
	}

	static func == ( left: ZNote, right: ZNote) -> Bool {
		let unequal = left != right // avoid infinite recursion by using negated version of this infix operator

		if  unequal,
			let rName = right.recordName,
			let lName =  left.recordName {
			return rName == lName
		}

		return !unequal
	}

	// MARK: - persistency
	// MARK: -

	func saveAsNote(_ attributedString: NSAttributedString?) {
		if  let            trait  = maybeNoteTrait,
			let       attributed  = attributedString {
			let            delta  = attributed.string.length - textRange.upperBound
			autoDelete            = false

			if  delta != 0 {
				textRange.length += delta      // correct text range, to avoid out of range for substring, on next line
			}

			let             text  = attributed.attributedSubstring(from: textRange)
			trait      .noteText  = NSMutableAttributedString(attributedString: text)

			if  gEssayTitleMode  != .sEmpty {
				let          name = attributed.string.substring(with: titleRange).replacingOccurrences(of: "\n", with: kEmpty)
				zone?   .zoneName = name
			}

			zone?.updateCoreDataRelationships()
		}
	}

	static func object(for id: String, isExpanded: Bool) -> NSObject? {
		var object: ZNote?

		if  let       zone = gRemoteStorage.maybeZoneForRecordName(id),
			zone.hasTrait(for: .tNote) {

			object = isExpanded ? ZEssay(zone) : ZNote(zone)

			if  let note = object {
				zone.noteMaybe = note
			}
		}

		return object
	}

	// MARK: - properties
	// MARK: -

	func toolName()  -> String? { return zone?.toolName() }
	func toolColor() -> ZColor? { return zone?.toolColor() }

	func identifier() -> String? {
		if  let id = zone?.identifier() {
			return kind + kColonSeparator + id
		}

		return nil
	}

	var paragraphStyle: NSMutableParagraphStyle {
		let tabStop = NSTextTab(textAlignment: .right, location: 6000.0, options: [:])
		let paragraph = NSMutableParagraphStyle()
		paragraph.tabStops = [tabStop]

		return paragraph
	}

	var titleAttributes: ZAttributesDictionary? {
		var result: ZAttributesDictionary?

		if	let      z = zone {
			let offset = NSNumber(floatLiteral: Double(kDefaultEssayTitleFontSize) / 7.0)
			result     = [.font : kEssayTitleFont, .paragraphStyle : paragraphStyle, .baselineOffset : offset]

			if  let  c = z.textColor {
				result?[.foregroundColor] = c
			}
		}

		return result
	}

	var spacerAttributes: ZAttributesDictionary? {
		var result = titleAttributes
		let light  = CGFloat((indentCount > 1) ? 4.0 : 20.0)
		if  let  z = zone,
			let  c = z.textColor?.lighter(by: light) {
			result?[.foregroundColor] = c
		}

		return result
	}

	var essayText : NSMutableAttributedString? {
		indentCount = 0
		let  result = noteText
		essayLength = result?.length ?? 0

		return result

	}

	var noteText: NSMutableAttributedString? {
		var result : NSMutableAttributedString?

		if  let (text, name) = updatedRangesFrom(noteTrait?.noteText) {
			result = NSMutableAttributedString(attributedString: text)

			if  gEssayTitleMode != .sEmpty {
				var        title = name + suffix
				var   attributes = titleAttributes

				if  indentCount != 0, gEssayTitleMode == .sFull {
					title        = prefix + title
				}

				if  let        z = zone, z.colorized,
					let    color = z.color?.lighter(by: 20.0).withAlphaComponent(0.5) {

					attributes?[.backgroundColor] = color
				}

				let attributedTitle = NSMutableAttributedString(string: title, attributes: attributes)

				result?.insert(kNoteSeparator,  at: 0)
				result?.insert(attributedTitle, at: 0)
			}

			result?.fixAllAttributes()
		}

		return result
	}

	func titleOffsetFor(_ mode: ZEssayTitleMode) -> Int {
		let isNotTitle = mode != .sTitle
		let    isEmpty = mode == .sEmpty
		let     isFull = mode == .sFull
		let      space = kNoteIndentSpacer.length
		let      tween = suffix.length + kNoteSeparator.length
		let      extra = indentCount - 2
		let      start = titleOffset
		var      total = 0

		if  isEmpty {
			total     += space
		} else {
			total     += start

			if  isFull {
				total += space + tween
			}

			if  let n  = zone?.zoneName?.length {
				total += n
			}
		}

		if  isNotTitle, extra > 0 {
			total     += space * extra
		}

		return total
	}

	@discardableResult func updatedRangesFrom(_ fromText: NSAttributedString?) -> (NSAttributedString, String)? {
		let   onlyTitle = gEssayTitleMode == .sTitle
		let     noTitle = gEssayTitleMode == .sEmpty
		if  let    text = fromText,
			let    name =   noTitle ? kEmpty : zone?.zoneName {
			let  indent = onlyTitle ? kEmpty : titleIndent
			let unicode = name.contains("􀅇") // it is two bytes
			let tLength = noTitle ? 0 :   name.length
			let iOffset = noTitle ? 0 : indent.length
			let tOffset = noTitle ? 0 : iOffset + tLength + kBlankLine.length + (unicode ? 2 : 1)
			titleRange  = NSRange(location: iOffset, length: tLength)
			textRange   = NSRange(location: tOffset, length: text.length)
			noteOffset  = 0

			return (text, name)
		}

		return nil
	}

	func updateIndentCount(relativeTo ancestor: Zone?) {
		if  let      start = ancestor,
			let      level = zone?.level {
			let difference = level - start.level
			indentCount    = difference + 1
		}
	}

	func bumpLocations(by offset: Int) {
		titleRange.location += offset
		textRange .location += offset
	}

	func upperBoundForNoteIn(_ range: NSRange) -> Int {
		let note = noteIn(range)

		return note.noteRange.upperBound + note.noteOffset
	}

	// MARK: - mutate
	// MARK: -

	func isLocked(within range: NSRange) -> Bool {
		let   titleStart = titleRange.lowerBound
		let     titleEnd = titleRange.upperBound
		let    textStart = textRange .lowerBound
		let      textEnd = textRange .upperBound
		let   rangeStart = range     .lowerBound
		let     rangeEnd = range     .upperBound
		let  beforeTitle = NSMakeRange(0, titleStart)
		let      between = NSMakeRange(titleEnd, textStart - titleEnd)
		let    afterText = NSMakeRange(textEnd, 0)
		let      isAfter = range.intersects(afterText)
		let     isBefore = range.intersects(beforeTitle)                          // before title
		let    isBetween = range.intersects(between) && between.length > 0        // between title and text
		let atTitleStart = titleStart == rangeStart                               // range begins at beginning of title
		let   atTitleEnd = titleEnd   == rangeEnd                                 // range ends at end of title
		let       locked = isAfter || (isBefore && !atTitleStart) || (isBetween && !atTitleEnd)

		return locked
	}

	// N.B. mutates title range

	func shouldAlterNote(inRange: NSRange, replacementLength: Int, adjustment: Int = 0) -> (ZAlterationType, Int) {
		var 	result  	  	        = ZAlterationType.eLock
		var      delta                  = 0

		if  zone?.userCanWrite ?? false,
		    let range 		            = inRange.inclusiveIntersection(noteRange)?.offsetBy(-noteOffset) {
			if  range                  == noteRange.offsetBy(-noteOffset),
				replacementLength      == 0 {
				result				    = .eDelete

				zone?.deleteNote()
			} else if !isLocked(within: range) {
				if  let   textIntersect = range.inclusiveIntersection(textRange) {
					delta               = replacementLength - textIntersect.length
					textRange  .length += delta
					result              = .eAlter
				}

				if  titleRange  .length > 0,
					let  titleIntersect = range.inclusiveIntersection(titleRange) {
					delta               = replacementLength - titleIntersect.length
					titleRange .length += delta
					textRange.location += delta
					result              = .eAlter
				}
			}
		}

		noteOffset += adjustment

		return 	(result, delta)
	}

	func shouldAlterEssay(in range: NSRange, replacementLength: Int) -> (ZAlterationType, Int) {
		var (result, delta) = shouldAlterNote(inRange: range, replacementLength: replacementLength)

		if  result == .eDelete {
			result  = .eExit
		}

		return (result, delta)
	}
}
