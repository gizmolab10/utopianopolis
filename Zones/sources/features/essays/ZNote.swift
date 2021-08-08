//
//  ZNote.swift
//  Seriously
//
//  Created by Jonathan Sand on 12/27/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

import Foundation

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
	var      offsetTextRange : NSRange   { return textRange.offsetBy(noteOffset) }
	var        lastTextRange : NSRange?  { return textRange }
	var       maybeNoteTrait : ZTrait?   { return zone?.traits  [.tNote] }
	var            noteTrait : ZTrait?   { return zone?.traitFor(.tNote) }
	var           recordName : String?   { return zone?.recordName }
	var                 kind : String    { return "note" }
	var               prefix : String    { return titleSpacer }
	var               suffix : String    { return kTab }
	var        noteSeparator : NSAttributedString { return kBlankLine }
	override var description : String    { return zone?.unwrappedName ?? kEmptyIdea }
	var          titleSpacer : String    { return kNoteIndentSpacer * indentCount }
	var          titleOffset : Int       { return titleSpacer.length }
	var      fullTitleOffset : Int       { return noteOffset + titleRange.location - titleOffset }
	var    lastTextIsDefault : Bool      { return maybeNoteTrait?.text == kEssayDefault }
	var               isNote : Bool      { return isMember(of: ZNote.self) }
	var    	            zone : Zone?

	func setupChildren() {}
	func updateNoteOffsets() {}
	func noteIn(_ range: NSRange) -> ZNote { return self }
	func injectIntoEssay(_ attributedString: NSAttributedString?) { injectIntoNote(attributedString) }
	func updateFontSize(_ increment: Bool) -> Bool { return updateTraitFontSize(increment) }
	func updateTraitFontSize(_ increment: Bool) -> Bool { return noteTrait?.updateEssayFontSize(increment) ?? false }

	init(zones: ZoneArray) {}

	init(_ zone: Zone?) {
		super.init()

		autoDelete = true
		self.zone = zone
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

	// MARK:- persistency
	// MARK:-

	func injectIntoNote(_ attributedString: NSAttributedString?) {
		if  let            trait  = maybeNoteTrait,
			let       attributed  = attributedString {
			let            delta  = attributed.string.length - textRange.upperBound
			autoDelete            = false

			if  delta != 0 {
				textRange.length += delta      // correct text range, to avoid out of range for substring, on next line
			}

			let             text  = attributed.attributedSubstring(from: textRange)
			trait      .noteText  = NSMutableAttributedString(attributedString: text)

			if  gEssayTitleMode != .sEmpty {
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

	// MARK:- properties
	// MARK:-

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

				result?.insert(noteSeparator,   at: 0)
				result?.insert(attributedTitle, at: 0)
			}

			result?.fixAllAttributes()
		}

		return result
	}

	@discardableResult func updatedRangesFrom(_ fromText: NSMutableAttributedString?) -> (NSMutableAttributedString, String)? {
		let hideTitles  = gEssayTitleMode == .sEmpty
		let justTitles  = gEssayTitleMode == .sTitle
		if  let    text = fromText,
			let    name = hideTitles ? kEmpty : zone?.zoneName {
			let  spacer = justTitles ? kEmpty : titleSpacer
			let hasGoof = name.contains("􀅇")
			let tLength = hideTitles ? 0 :  name  .length
			let sOffset = hideTitles ? 0 :  spacer.length
			let tOffset = hideTitles ? 0 :  sOffset + tLength + kBlankLine.length + 1 + (hasGoof ? 1 : 0)
			titleRange  = NSRange(location: sOffset, length: tLength)
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

	// MARK:- mutate
	// MARK:-

	func reset() {
		setupChildren()
	}

	func isLocked(within range: NSRange) -> Bool {
		if  gEssayTitleMode == .sEmpty {
			return false
		} else {
			let     ranEnd = range     .upperBound
			let     titEnd = titleRange.upperBound
			let   titStart = titleRange.lowerBound
			let  textStart = textRange .lowerBound
			let   ranStart = range     .lowerBound
			let atTitStart = titStart == ranStart                               // range begins at beginning of title
			let   atTitEnd = titEnd   == ranEnd                                 // range ends at end of title
			let  beforeTit = NSMakeRange(0, titleRange.lowerBound)
			let    between = NSMakeRange(titEnd, textStart - titEnd)
			let   isBefore = beforeTit.intersects(range)         // before title
			let  isBetween = between  .intersects(range)                        // between title and text
			let  straddles = range    .intersects(between)                      // begins in title ends in text
			let     locked = ((straddles || isBetween) && !atTitEnd) || (isBefore && !atTitStart)

			return locked
		}
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

				if  let  titleIntersect = range.inclusiveIntersection(titleRange) {
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

	func shouldAlterEssay(_ range: NSRange, replacementLength: Int) -> (ZAlterationType, Int) {
		var (result, delta) = shouldAlterNote(inRange: range, replacementLength: replacementLength)

		if  result == .eDelete {
			result  = .eExit
		}

		return (result, delta)
	}
}
