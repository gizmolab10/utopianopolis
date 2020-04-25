//
//  ZNote.swift
//  Zones
//
//  Created by Jonathan Sand on 12/27/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation

enum ZAlterationType: Int {
	case eDelete
	case eAlter
	case eLock
	case eExit
}

class ZNote: NSObject, ZIdentifiable, ZToolable {
	var    zone  	         : Zone?
	var    children          = [ZNote]()
	var    autoDelete        = false		// true means delete this note on exit from essay mode
	var    essayLength       = 0
	var    noteOffset        = 0
	var    noteTraitMaybe    : ZTrait?   { return zone?.traits[  .tNote] }
	var    noteTrait         : ZTrait?   { return zone?.traitFor(.tNote) }
	var    prefix            : String    { return "note" }
	override var description : String    { return zone?.unwrappedName ?? kEmptyIdea }
	var    isNote            : Bool      { return isMember(of: ZNote.self) }
	var    lastTextIsDefault : Bool      { return noteTraitMaybe?.text == kEssayDefault }
	var    fullTitleOffset   : Int       { return noteOffset + titleRange.location - 2 }
	var    fullTitleRange    : NSRange   { return NSRange(location:   fullTitleOffset, length: titleRange.length + 3) }
	var         noteRange    : NSRange   { return NSRange(location:   noteOffset, length:  textRange.upperBound) }
	var   offsetTextRange    : NSRange   { return textRange .offsetBy(noteOffset) }
	var     lastTextRange    : NSRange?  { return textRange }
	var        titleRange    = NSRange()
	var         textRange    = NSRange()

	func setupChildren() {}
	func updateOffsets() {}
	func recordName() -> String? { return zone?.recordName() }
	func saveEssay(_ attributedString: NSAttributedString?) { saveNote(attributedString) }
	func updateFontSize(_ increment: Bool) -> Bool { return updateTraitFontSize(increment) }
	func updateTraitFontSize(_ increment: Bool) -> Bool { return noteTrait?.updateEssayFontSize(increment) ?? false }

	init(_ zone: Zone?) {
		super.init()

		autoDelete = true
		self.zone = zone
	}

	static func == ( left: ZNote, right: ZNote) -> Bool {
		let unequal = left != right // avoid infinite recursion by using negated version of this infix operator

		if  unequal && left.zone?.record != nil && right.zone?.record != nil {
			return left.zone?.recordName == right.zone?.recordName
		}

		return !unequal
	}

	// MARK:- persistency
	// MARK:-

	func saveNote(_ attributedString: NSAttributedString?) {
		if  let attributed = attributedString,
			let       note = noteTraitMaybe {
			let     string = attributed.string
			let       text = attributed.attributedSubstring(from: textRange)
			let      title = string.substring(with: titleRange).replacingOccurrences(of: "\n", with: "")
			note .noteText = text.mutableCopy() as? NSMutableAttributedString // invokes note.needSave()
			zone?.zoneName = title
			autoDelete     = false

			noteTrait?.needSave()
			zone?.needSave()
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

	var essayText : NSMutableAttributedString? {
		let  result = noteText
		essayLength = result?.length ?? 0

		return result

	}

	var noteText: NSMutableAttributedString? {
		var result:    NSMutableAttributedString?

		if  let    name = zone?.zoneName,
			let    text = noteTrait?.noteText {
			let  spacer = "  "
			let sOffset = spacer.length
			let tOffset = sOffset + name.length + gBlankLine.length + 1
			let   title = NSMutableAttributedString(string: spacer + name + kTab, attributes: titleAttributes)
			result      = NSMutableAttributedString()
			titleRange  = NSRange(location: sOffset, length: name.length)
			textRange   = NSRange(location: tOffset, length: text.length)
			noteOffset  = 0

			result?.insert(text,       at: 0)
			result?.insert(gBlankLine, at: 0)
			result?.insert(title,      at: 0)

			colorizeTitle(result)

			result?.fixAllAttributes()
		}

		return result
	}

	func colorizeTitle(_ text: NSMutableAttributedString?) {
		if  let     z = zone, z.colorized,
			let color = z.color?.lighter(by: 20.0).withAlphaComponent(0.5) {

			text?.addAttribute(.backgroundColor, value: color, range: fullTitleRange)
		}
	}

	func bumpOffsets(by offset: Int) {
		titleRange = titleRange.offsetBy(offset)
		textRange  = textRange .offsetBy(offset)
	}

	// MARK:- mutate
	// MARK:-

	func delete() {
		zone?.removeTrait(for: .tNote)
		gEssayRing.removeFromStack(self) // display prior essay
		gRingView?.setNeedsDisplay()
	}

	func reset() {
		noteTraitMaybe?.clearSave()
		setupChildren()
	}

	func isLocked(for range: NSRange, _ length: Int) -> Bool {
		let     start = range     .lowerBound
		let textStart = textRange .lowerBound
		let       end = range     .upperBound
		let   textEnd = textRange .upperBound
		let  titleEnd = titleRange.upperBound

		return
			(start  > titleEnd && start <  textStart) ||
			(  end  > titleEnd &&   end <  textStart) ||
			(start  < titleEnd &&   end >= textStart) ||
			(length == 0       && start >= textEnd)
	}

	func shouldAlterEssay(_ range: NSRange, length: Int) -> (ZAlterationType, Int) {
		var (result, delta) = shouldAlterNote(range, length: length)

		if  result == .eDelete {
			result  = .eExit
		}

		return (result, delta)
	}

	func shouldAlterNote(_ iRange: NSRange, length: Int, adjustment: Int = 0) -> (ZAlterationType, Int) {
		var 	result  	  	        = ZAlterationType.eLock
		var      delta                  = 0

		if  zone?.userCanWrite ?? false,
		    let range 		            = iRange.inclusiveIntersection(noteRange)?.offsetBy(-noteOffset) {
			if  range                  == noteRange.offsetBy(-noteOffset) {
				result				    = .eDelete

				delete()
			} else if !isLocked(for: range, length) {
				if  let   textIntersect = range.inclusiveIntersection(textRange) {
					delta               = length - textIntersect.length
					textRange  .length += delta
					result              = .eAlter
				}

				if  let  titleIntersect = range.inclusiveIntersection(titleRange) {
					delta               = length - titleIntersect.length
					titleRange .length += delta
					textRange.location += delta
					result              = .eAlter
				}
			}
		}

		noteOffset += adjustment

		return 	(result, delta)
	}

}
