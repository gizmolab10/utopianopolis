//
//  ZTextEditor.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/19/18.
//  Copyright © 2018 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
import AppKit
#elseif os(iOS)
import UIKit
#endif

let gTextEditor = ZTextEditor()
var gCurrentlySelectedText  : String?         { return gCurrentlyEditingWidget?.text?.substring(with: gTextEditor.selectedRange) }
var gCurrentlyEditingWidget : ZoneTextWidget? { return gTextEditor.currentTextWidget }

class ZTextPack: NSObject {

	let          createdAt =           Date()
    var         packedZone :           Zone?
    var        packedTrait :         ZTrait?
    var       originalText :         String?
    var         textWidget : ZoneTextWidget? { return widget?.textWidget }
    var             widget :     ZoneWidget? { return packedZone?.widget }
    var   adequatelyPaused :           Bool  { return Date().timeIntervalSince(createdAt) > 0.1 }

    var displayType: String {
        if  let        trait = packedTrait {
            return     trait.emptyName
        } else if let  zone  = packedZone {
            return     zone.emptyName
        }

        return kNoValue
    }

	var emptyName: String {
		if  let        trait = packedTrait {
			return     trait  .emptyName
		} else if let  zone  = packedZone {
			return     zone   .emptyName
		}

		return kNoValue
	}

    var unwrappedName: String {
        if  let        trait = packedTrait {
            return     trait  .unwrappedName
        } else if let  zone  = packedZone {
            return     zone   .unwrappedName
        }

        return kNoValue
    }

    var textWithSuffix: String {
        var   result = displayType

        if  let zone = packedZone {
            result   = zone.unwrappedNameWithEllipses
			let dups = zone.duplicateZones.count
			let  bad = zone.hasBadRecordName
            var need = dups

			if  bad {                            // bad trumps dups
				need = -1
			} else if need == 0 {                // dups trump count mode
				switch gCountsMode {
					case .fetchable: need = zone.indirectCount
					case .progeny:   need = zone.progenyCount + 1
					default:         return result
				}
			}

            var suffix: String?

            // //////////////////////////////////
            // add suffix for "show counts as" //
            // //////////////////////////////////

			if  gPrintModes.contains(.dNames), let name = zone.recordName {
                suffix = name
			} else {
				var showNeed = (need > 1) && (!zone.expanded || (gCountsMode == .progeny))

				if (dups > 0 && need > 0 && gShowDuplicates) || bad {
					showNeed = true
				}

				if  showNeed {
					suffix = String(describing: need)
				}
			}

            if  let s = suffix {
                result.append("  ( \(s) )")
            }
        }

        return result
    }

    // MARK:- internals: editing zones and traits
    // MARK:-

	convenience init(_ iZRecord: ZRecord) {
        self.init()
        self.setup(for: iZRecord)
    }

    func updateText(isEditing: Bool = false) {
		var        text = isEditing ? unwrappedName : textWithSuffix

		if !isEditing,
			text.length > 18,
			let    type = widget?.type,
			!type.contains(.tExemplar),
			!type.contains(.tBigMap) {                                  // is in small map
			let  isLine = text[0] == "-"
			text        = text.substring(toExclusive: isLine ? 20 : 15) // shorten to fit (in small map area)

			if !isLine {
				text.append("...")
			}
		}

		textWidget?.text = text
	}

    func setup(for iZRecord: ZRecord) {
        packedTrait  = iZRecord as? ZTrait
        packedZone   = iZRecord as? Zone ?? packedTrait?.ownerZone
        originalText = unwrappedName

        textWidget?.text = originalText
    }

    func isEditing(_ iZRecord: ZRecord) -> Bool {
        return packedZone == iZRecord || packedTrait == iZRecord
    }

    func updateWidgetsForEndEdit() {
		if  let z = packedZone,
			let w = gWidgets.widgetForZone(z) {
			let t = w.textWidget
			w.layoutDots()
			w.revealDot.setNeedsDisplay()
			w.setNeedsDisplay()
			t.abortEditing()      // NOTE: this does NOT remove selection highlight
			t.deselectAllText()
			t.updateTextColor()
			t.layoutText()
		}
    }

    func capture(_ iText: String?) {
		if  let text           = iText == displayType ? nil : iText {
			if  let     trait  = packedTrait {                             // traits take logical priority
				trait.ownerZone?.setTraitText(text, for: trait.traitType)
			} else if let zone = packedZone {                              // ignore zone if editing a trait, above
				zone.records?.removeFromLocalSearchIndex(nameOf: zone)

				zone.zoneName  = text

				zone.addToLocalSearchIndex()
			}
		}
	}


    func removeSuffix(from iText: String?) -> String? {
        var newText: String?

        if  let components = iText?.components(separatedBy: "  (") {
            newText        = components[0]

            if  newText == displayType || newText == kEmpty {
                newText  = nil
            }
        }

        return newText
    }

    func captureTextAndUpdateWidgets(_ iText: String?) {
        capture(iText)
        updateWidgetsForEndEdit()
    }

	func captureText(_ iText: String?, redrawSync: Bool = false) {
		if [emptyName, kEmpty].contains(iText),
			let                 type  = packedTrait?.traitType {
			packedZone?.removeTrait(for: type)                     // trait text was deleted (email, hyperlink)
		} else if              iText != originalText {
            let              newText  = removeSuffix(from: iText)
            gTextCapturing            = true

            if  let                w  = textWidget {
                let         original  = originalText
                prepareUndoForTextChange(gUndoManager) {
                    self.originalText = w.text

					self.captureText(original, redrawSync: true)
                    w.updateGUI()
                }
            }

            captureTextAndUpdateWidgets(newText)

			if  packedTrait == nil { // only if zone name is being edited
				updateBookmarkAssociates()
			}
		}

		gTextCapturing = false

		if  redrawSync {
			gRedrawMaps()
		}
    }

    func updateBookmarkAssociates() {
        if  var       zone = packedZone,
            let    newText = zone.zoneName {

            if  let target = zone.bookmarkTarget {
                zone       = target
                
                ZTextPack(target).captureTextAndUpdateWidgets(newText)
            }
            
            for bookmark in zone.bookmarksTargetingSelf {
                ZTextPack(bookmark).captureTextAndUpdateWidgets(newText)
            }
        }
    }

	func prepareUndoForTextChange(_ manager: UndoManager?,_ onUndo: @escaping Closure) {
        if  let text = textWidget?.text,
            text    != originalText {
            manager?.registerUndo(withTarget:self) { iUndoSelf in
                let                newText = iUndoSelf.textWidget?.text ?? kEmpty
                iUndoSelf.textWidget?.text = iUndoSelf.originalText
                iUndoSelf.originalText     = newText

                onUndo()
            }
        }
    }

}

class ZTextEditor: ZTextView {

    var  cursorOffset  	    : CGFloat?
    var currentOffset 	    : CGFloat?
	var currentEdit 	    : ZTextPack?
	var currentlyEditedZone : Zone?           { return currentEdit?.packedZone }
	var currentTextWidget   : ZoneTextWidget? { return currentlyEditedZone?.widget?.textWidget }
	var currentZoneName	    : String          { return currentlyEditedZone?.zoneName ?? kEmpty }
	var currentFont 	    : ZFont           { return currentTextWidget?.font ?? gWidgetFont }
	var atEnd 	            : Bool            { return selectedRange.lowerBound == currentTextWidget?.text?.length ?? -1 }
	var atStart  	        : Bool            { return selectedRange.upperBound == 0 }

    // MARK:- editing
    // MARK:-

    func clearOffset() { currentOffset = nil }

	func clearEdit() {
		currentEdit = nil

		clearOffset()
		fullResign()
		gSetBigMapMode()
	}

    func cancel() {
        if  let    e = currentEdit,
            let zone = currentlyEditedZone {
            clearEdit()
            zone.grab()
            e.updateWidgetsForEndEdit()
        }
    }

    @discardableResult func updateText(inZone: Zone?, isEditing: Bool = false) -> ZTextPack? {
        var pack: ZTextPack?
        
        if  let zone = inZone {
            pack = ZTextPack(zone)
            pack?.updateText(isEditing: isEditing)
        }
        
        return pack
    }

    @discardableResult func edit(_ zRecord: ZRecord, setOffset: CGFloat? = nil, immediately: Bool = false) -> ZTextEditor {
        if  (currentEdit == nil || !currentEdit!.isEditing(zRecord)) { 			// prevent infinite recursion inside becomeFirstResponder, called below
            let        pack = ZTextPack(zRecord)
			if  let    zone = pack.packedZone,
				zone.userCanWrite {
				currentEdit = pack

				printDebug(.dEdit, " MAYBE   " + zone.unwrappedName)
				deferEditingStateChange()
				pack.updateText(isEditing: true)
				gSelecting.ungrabAll(retaining: [zone])		// so crumbs will appear correctly
				gSetEditIdeaMode()

				if  let textWidget = zone.widget?.textWidget {
					textWidget.enableUndo()
					textWidget.applyConstraints()
					textWidget.becomeFirstResponder()
				}

				if  let at = setOffset ?? gCurrentMouseDownLocation {
					setCursor(at: at)
				}

				gSignal([.spCrumbs, .spPreferences])
			}
        }

		return self
    }

	func placeCursorAtEnd() {
        selectedRange = NSMakeRange(-1, 0)
    }

	func applyPreservingOffset(_ closure: Closure) {
        let o = currentOffset
        
        closure()
        
        currentOffset = o
    }

	func applyPreservingEdit(_ closure: Closure) {
        let e = currentEdit

        applyPreservingOffset {
            closure()
        }
        
        currentEdit = e
    }

    func quickStopCurrentEdit() {
        if  let e = currentEdit {
            applyPreservingEdit {
                capture()
                e.packedZone?.grab()
            }
        }
    }

	func stopCurrentEdit(forceCapture: Bool = false, andRedraw: Bool = true) {
        if  let    e = currentEdit, !gIsEditingStateChanging {
			let zone = e.packedZone

			capture(force: forceCapture)

			clearEdit()
			fullResign()
			e.updateWidgetsForEndEdit()
			zone?.grab()

			if  andRedraw {
				gRedrawMaps(for: zone)
			}
        }
    }

    func deferEditingStateChange() {
        gIsEditingStateChanging     = true

        FOREGROUND(after: 0.1) {
            gIsEditingStateChanging = false
        }
    }

	func capture(force: Bool = false) {
        if  let current = currentEdit, let text = current.textWidget?.text, (!gTextCapturing || force) {
			printDebug(.dEdit, " CAPTURE \(text)")
            current.captureText(text)
        }
    }

    func assign(_ iText: String?, to iZone: Zone?) {
        if  let zone = iZone {
            ZTextPack(zone).captureText(iText)
        }
    }

    func prepareUndoForTextChange(_ manager: UndoManager?,_ onUndo: @escaping Closure) {
        currentEdit?.prepareUndoForTextChange(manager, onUndo)
    }

	
	// MARK:- selecting
	// MARK:-

	func selectAllText() {
		let range = NSRange(location: 0, length: currentTextWidget?.text?.length ?? 0)

		deferEditingStateChange()
		selectedRange = range
	}

	func selectText(_ iText: String?) {
		if	let   text =  currentTextWidget?.text?.searchable,
			let ranges = text.rangesMatching(iText),
			ranges.count > 0 {
			let range  = ranges[0]
			selectedRange = range
		}
	}
	
	// MARK:- events
	// MARK:-

	@IBAction func genericMenuHandler(_ iItem: ZMenuItem?) { gAppDelegate?.genericMenuHandler(iItem) }

    func moveOut(_ iMoveOut: Bool) {
        let revealed = currentlyEditedZone?.expanded ?? false

		gTemporarilySetTextEditorHandlesArrows()   // done first, this timer is often not be needed, KLUDGE to fix a bug where arrow keys are ignored

        let editAtOffset: FloatClosure = { iOffset in
            if  let grabbed = gSelecting.firstSortedGrab {
                gSelecting.ungrabAll()
                self.edit(grabbed, setOffset: iOffset, immediately: revealed)
            }

			gTextEditorHandlesArrows = false       // done last
        }

        if  iMoveOut {
            quickStopCurrentEdit()
            gMapEditor.moveOut { reveal in
                editAtOffset(100000000.0)
            }
        } else if currentlyEditedZone?.children.count ?? 0 > 0 {
            quickStopCurrentEdit()
            gMapEditor.moveInto { reveal in
                editAtOffset(0.0)
            }
        }
    }

	func editingOffset(_ atStart: Bool) -> CGFloat {
        return currentTextWidget?.offset(for: selectedRange, atStart) ?? 0.0
    }

	func moveUp(_ iMoveUp: Bool, stopEdit: Bool) {
        currentOffset   = currentOffset ?? editingOffset(iMoveUp)
        let currentZone = currentlyEditedZone
        let      isHere = currentZone == gHere
        let           e = currentEdit // for the case where stopEdit is true

        if  stopEdit {
            applyPreservingOffset {
                capture()
                currentZone?.grab()
            }
        }
        
        if  var original = currentZone {
            gMapEditor.moveUp(iMoveUp, [original], targeting: currentOffset) { iKinds in
                gControllers.signalFor(nil, multiple: iKinds) {
                    if  isHere {
                        self.currentOffset = currentZone?.widget?.textWidget.offset(for: self.selectedRange, iMoveUp)  // offset will have changed when current == here
                    }
                    
                    if  stopEdit,
                        let first = gSelecting.firstSortedGrab {
                        original  = first
                        
                        if  original != currentZone { // if move up (above) does nothing, ignore
                            self.edit(original)
                        } else {
                            self.currentEdit = e // restore after capture sets it to nil

                            gSelecting.ungrabAll()
                            e?.textWidget?.becomeFirstResponder()
                        }
                    } // else widgets are wrong
                    
                    FOREGROUND(after: 0.01) {
                        self.setCursor(at: self.currentOffset)
                    }
                }
            }
        }
    }

	func setCursor(at iOffset: CGFloat?) {
        gTextEditorHandlesArrows = false
        if  var     offset = iOffset,
            let       zone = currentlyEditedZone,
            let         to = currentTextWidget {
			var      point = CGPoint.zero
            point          = to.convert(point, from: nil)
			offset        += point.x - 3.0   // subtract half the average character width -> closer to user expectation
            let       name = zone.unwrappedName
            let   location = name.location(of: offset, using: currentFont)

			printDebug(.dEdit, " AT \(location)    \(name)")
            self.selectedRange = NSMakeRange(location, 0)
        }
    }
    
}
