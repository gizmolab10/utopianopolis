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
	var          titleInsets = 0
	var           noteOffset = 0
	var           autoDelete = false		// true means delete this note on exit from essay mode
	var             children = [ZNote]()
	var           titleRange = NSRange()
	var            textRange = NSRange()
	var            noteRange : NSRange   { return NSRange(location: noteOffset, length: textRange.upperBound) }
	var      offsetTextRange : NSRange   { return textRange.offsetBy(noteOffset) }
	var        lastTextRange : NSRange?  { return textRange }
	var       maybeNoteTrait : ZTrait?   { return zone?.traits[  .tNote] }
	var            noteTrait : ZTrait?   { return zone?.traitFor(.tNote) }
	var           recordName : String?   { return zone?.recordName }
	var               prefix : String    { return "note" }
	override var description : String    { return zone?.unwrappedName ?? kEmptyIdea }
	var          titleOffset : Int       { return titleInsets * kNoteIndentSpacer.length }
	var      fullTitleOffset : Int       { return noteOffset + titleRange.location - titleOffset }
	var    lastTextIsDefault : Bool      { return maybeNoteTrait?.text == kEssayDefault }
	var               isNote : Bool      { return isMember(of: ZNote.self) }
	var    	            zone : Zone?

	func setupChildren() {}
	func updateNoteOffsets() {}
	func noteIn(_ range: NSRange) -> ZNote { return self }
	func saveEssay(_ attributedString: NSAttributedString?) { saveNote(attributedString) }
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

	func saveNote(_ attributedString: NSAttributedString?) {
		if  let attributed = attributedString,
			let       note = maybeNoteTrait {
			let       text = attributed.attributedSubstring(from: textRange)
			note .noteText = NSMutableAttributedString(attributedString: text)    // invokes note.needSave()
			autoDelete     = false

			if  gShowEssayTitles {
				let       name = attributed.string.substring(with: titleRange).replacingOccurrences(of: "\n", with: "")
				zone?.zoneName = name
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
			return prefix + kColonSeparator + id
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
			let offset = NSNumber(floatLiteral: Double(gEssayTitleFontSize) / 7.0)
			result     = [.font : gEssayTitleFont, .paragraphStyle : paragraphStyle, .baselineOffset : offset]

			if  let  c = z.textColor {
				result?[.foregroundColor] = c
			}
		}

		return result
	}

	var spacerAttributes: ZAttributesDictionary? {
		var result = titleAttributes
		let light  = CGFloat((titleInsets > 1) ? 4.0 : 20.0)
		if  let  z = zone,
			let  c = z.textColor?.lighter(by: light) {
			result?[.foregroundColor] = c
		}

		return result
	}

	var essayText : NSMutableAttributedString? {
		titleInsets = 0
		let  result = noteText
		essayLength = result?.length ?? 0

		return result

	}

	var noteText: NSMutableAttributedString? {
		var result : NSMutableAttributedString?

		if  let (text, name) = updatedRanges() {
			result = NSMutableAttributedString()

			result?        .insert(text,       at: 0)

			if  gShowEssayTitles {
				var      title = name + kTab
				var attributes = titleAttributes

				if  titleInsets != 0 {
					let spacer = kNoteIndentSpacer * titleInsets
					title      = spacer + title
				}

				if  let      z = zone, z.colorized,
					let  color = z.color?.lighter(by: 20.0).withAlphaComponent(0.5) {

					attributes?[.backgroundColor] = color
				}

				let attributedTitle = NSMutableAttributedString(string: title, attributes: attributes)

				result?.insert(gBlankLine,      at: 0)
				result?.insert(attributedTitle, at: 0)
			}

			result?.fixAllAttributes()
		}

		return result
	}

	@discardableResult func updatedRanges() -> (NSMutableAttributedString, String)? {
		let hideTitles  = !gShowEssayTitles
		if  let    name = hideTitles ? "" : zone?.zoneName,
			let    text = noteTrait?.noteText {
			let  spacer = kNoteIndentSpacer * titleInsets
			let sOffset = hideTitles ? 0 : spacer.length
			let hasGoof = name.contains("􀅇")
			let tOffset = hideTitles ? 1 :  sOffset + name.length + gBlankLine.length + 1 + (hasGoof ? 1 : 0)
			titleRange  = NSRange(location: sOffset, length: name.length)
			textRange   = NSRange(location: tOffset, length: text.length)
			noteOffset  = 0

			return (text, name)
		}

		return nil
	}

	func updateTitleInsets(relativeTo ancestor: Zone?) {
		if  let start = ancestor,
			let level = zone?.level {
			let difference = level - start.level
			titleInsets = difference + 1
		}
	}

	func bumpRanges(by offset: Int) {
		titleRange = titleRange.offsetBy(offset)
		textRange  = textRange .offsetBy(offset)
	}

	func upperBoundForNoteIn(_ range: NSRange) -> Int {
		let    note = noteIn(range)

		return note.noteRange.upperBound + note.noteOffset
	}

	// MARK:- mutate
	// MARK:-

	func reset() {
		setupChildren()
	}

	func isLocked(within range: NSRange) -> Bool {
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
		let   isLocked = ((straddles || isBetween) && !atTitEnd) || (isBefore && !atTitStart)

		return isLocked
	}

	// N.B. mutates title range

	func shouldAlterNote(inRange: NSRange, replacementLength: Int, adjustment: Int = 0) -> (ZAlterationType, Int) {
		var 	result  	  	        = ZAlterationType.eLock
		var      delta                  = 0

		if  zone?.userCanWrite ?? false,
		    let range 		            = inRange.inclusiveIntersection(noteRange)?.offsetBy(-noteOffset) {
			if  range                  == noteRange.offsetBy(-noteOffset) {
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
