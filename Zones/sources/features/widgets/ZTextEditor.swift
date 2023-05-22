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

let gTextEditor             = ZTextEditor()
var gCurrentlyEditingWidget : ZoneTextWidget? { return gTextEditor.currentTextWidget }
var gCurrentlySelectedText  : String?         { return gCurrentlyEditingWidget?.text?.substring(with: gTextEditor.selectedRange) }
var gCurrentlyEditingZone   : Zone?           { return gCurrentlyEditingWidget?.widgetZone }

class ZTextPack: NSObject {

	let        createdAt =           Date()
    var       packedZone :           Zone?
    var      packedTrait :         ZTrait?
    var     originalText :         String?
	var    unwrappedName :         String  { return packedTrait?.unwrappedName ?? packedZone?.unwrappedName ?? kNoValue }
    var adequatelyPaused :           Bool  { return Date().timeIntervalSince(createdAt) > 0.1 }
	var       textWidget : ZoneTextWidget? { return widget?.textWidget }
	var           widget :     ZoneWidget? { return packedZone?.widget }


	var emptyName: String {
		if  let        trait = packedTrait {
			return     trait  .emptyName
		} else if let  zone  = packedZone {
			return     zone   .emptyName
		}

		return kNoValue
	}

    var textWithSuffix: String {
        var   result = emptyName

        if  let zone = packedZone {
			result   = zone.unwrappedNameWithEllipses(zone.isInFavorites)
			let dups = zone.duplicateZones.count
			let  bad = zone.hasBadRecordName
            var need = dups

			if  bad {                            // bad trumps dups
				need = -1
			} else if need == 0 {                // dups trump count mode
				switch gCountsMode {
					case .fetchable: need = zone.indirectCount
					case .progeny:   need = zone.progenyCount
					default:         return result
				}
			}

            var suffix: String?

            // /////////////////////////////// //
            // add suffix for "show counts as" //
            // /////////////////////////////// //

			if  gPrintModes.contains(.dNames), let name = zone.recordName {
                suffix = name
			} else {
				var showNeed = (need > 1) && (!zone.isExpanded || (gCountsMode == .progeny))

				if (dups > 0 && need > 0 && gIsShowingDuplicates) || bad {
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

    // MARK: - initialize
    // MARK: -

	convenience init(_ iZRecord: ZRecord) {
        self.init()
        self.setup(for: iZRecord)
    }

	func updatePackText(isEditing: Bool = false) {
		var          text = isEditing ? unwrappedName : textWithSuffix

		if  !isEditing,
		    let         w = widget {
			let      type = w.mapType
			let  isLinear = w.isLinearMode
			let threshold = isLinear ? 18 : 20
			if  threshold < text.length,
				!type.isExemplar,
				!type.isMainMap || !isLinear {

				// ////////////////////////////// //
				// if in favorites or is circular //
				// if not editing, clip and       //
				// if favorite, add ellipses      //
				// ////////////////////////////// //

				let  isLine = text.isLine
				text        = text.substring(toExclusive: isLinear ? isLine ? 20 : 15 : 10) // shorten to fit (in favorites map area or in circles)

				if !isLine {
					text.append(kEllipsis)
				}
			}
		}

		textWidget?.setText(text)
	}

    func setup(for zRecord: ZRecord) {
		packedTrait  = zRecord.maybeTrait                          // do this first
		packedZone   = zRecord.maybeZone ?? packedTrait?.ownerZone
        originalText = unwrappedName

		textWidget?.setText(originalText)
    }

    func isEditing(_ iZRecord: ZRecord) -> Bool {
        return packedZone == iZRecord || packedTrait == iZRecord
    }

    func removeSuffix(from iText: String?) -> String? {
        var newText: String?

        if  let components = iText?.components(separatedBy: "  (") {
            newText        = components[0]

            if  newText   == emptyName || newText == kEmpty {
                newText    = nil
            }
        }

        return newText
    }

    func updateBookmarkAssociates() {
        if  var       zone = packedZone,
            let    newText = zone.zoneName {

            if  let target = zone.bookmarkTarget {
                zone       = target
                
                ZTextPack(target).captureTextAndUpdateWidgets(newText)
            }

			zone.applyToAllBookmarksTargetingSelf { bookmark in
                ZTextPack(bookmark).captureTextAndUpdateWidgets(newText)
            }
        }

		FOREGROUND(after: 0.001) { gRelayoutMaps() }
    }

	func prepareUndoForTextChange(_ manager: UndoManager?,_ onUndo: @escaping Closure) {
        if  let text = textWidget?.text,
            text    != originalText {
            manager?.registerUndo(withTarget:self) { iUndoSelf in
                let            newText = iUndoSelf.textWidget?.text ?? kEmpty
				iUndoSelf.originalText = newText

				iUndoSelf.textWidget?.setText(iUndoSelf.originalText)
                onUndo()
            }
        }
    }

	// MARK: - capture
	// MARK: -

	func capture(_ iText: String?) {
		if  let text           = iText, text != kEmpty {
			if  let     trait  = packedTrait {            // traits take logical priority (i.e., ignore zone if editing a trait)
				trait.ownerZone?.setTraitText(text, for: trait.traitType)
			} else if let zone = packedZone {
				zone.zRecords?.removeFromLocalSearchIndex(nameOf: zone)
				zone.setNameForSelfAndBookmarks(to: text.removeProblemCharacters)
				zone.addToLocalSearchIndex()
			}
		}
	}

	func captureTextAndUpdateWidgets(_ iText: String?) {
		capture(iText)
		updateWidgetsForEndEdit()
	}

	func captureText(_ text: String?) {
		if (text == kEmpty || text == emptyName) {
			if  let           type  = packedTrait?.traitType {
				packedZone?.removeTrait(for: type)                     // trait text was deleted (email, hyperlink)
			}
		} else if             text != originalText {
			let            newText  = removeSuffix(from: text)
			gTextCapturing          = true
			if  let              w  = textWidget {
				let       original  = originalText
				prepareUndoForTextChange(gUndoManager) { [self] in
					originalText    = w.text

					captureText(original)
					w.updateGUI()
				}
			}

			captureTextAndUpdateWidgets(newText)

			if  packedTrait == nil { // only if zone name is being edited
				updateBookmarkAssociates()
			}
		}

		gTextCapturing = false
	}

	func updateWidgetsForEndEdit() {
		if  let z = packedZone,
			let w = gWidgets.widgetForZone(z),
			let t = w.textWidget {
			t.abortEditing()      // NOTE: this does NOT remove selection highlight
			t.deselectAllText()
			t.updateTextColor()
			z.updateEditorText()
		}
	}

}

class ZTextEditor: ZTextView {

    var  cursorOffset        : CGFloat?
    var  currentOffset       : CGFloat?
	var  currentEdit         : ZTextPack?
	var  currentlyEditedZone : Zone?           { return currentEdit?.packedZone }
	var  currentTextWidget   : ZoneTextWidget? { return currentlyEditedZone?.widget?.textWidget }
	var  currentZoneName     : String          { return currentlyEditedZone?.zoneName ?? kEmpty }
	var  currentFont         : ZFont           { return currentTextWidget?.font ?? gMainFont }
	var  atEnd               : Bool            { return selectedRange.lowerBound == currentTextWidget?.text?.length ?? -1 }
	var  atStart             : Bool            { return selectedRange.upperBound == 0 }
	func clearOffset()                         { currentOffset = nil }

	// MARK: - edit
	// MARK: -

    @discardableResult func edit(_ zRecord: ZRecord, setOffset: CGFloat? = nil, immediately: Bool = false) -> ZTextEditor {
        if  (currentEdit == nil || !currentEdit!.isEditing(zRecord)) { 			// prevent infinite recursion inside assignAsFirstResponder, called below
            let        pack = ZTextPack(zRecord)
			if  let    zone = pack.packedZone,
				zone.userCanWrite {
				currentEdit = pack
				var  offset = setOffset

				printDebug(.dEdit, " EDIT    " + zone.unwrappedName)
				deferEditingStateChange()
				pack.updatePackText(isEditing: true)        // updates drawnSize of textWidget
				gSelecting.ungrabAll(retaining: [zone])		// so crumbs will appear correctly
				gRelayoutMaps()
				gSetEditIdeaMode()

				if  let t = zone.textWidget {
					t.enableUndo()
					assignAsFirstResponder(t)

					if  offset     == nil,
						let current = gCurrentOffset {      // from mouse down event
						offset      = current + t.frame.minX
					}
				}

				if  let at = offset {
					setCursor(at: at)
				}

				gSignal([.spCrumbs, .spPreferences])
			}
        }

		return self
    }

	@discardableResult func updateEditorText(inZone: Zone?) -> ZTextPack? {
		if  let zone = inZone {
			var pack = currentEdit
			let edit = zone == currentEdit?.packedZone
			if !edit {
				pack = ZTextPack(zone)   // use "scratchpad text pack" to update text for ALL non-edited ideas
			}

			pack?.updatePackText(isEditing: edit)

			return pack
		}

		return nil
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

    func deferEditingStateChange() {
        gIsEditingStateChanging     = true

        FOREGROUND(after: 0.1) {
            gIsEditingStateChanging = false
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

	// MARK: - stop
	// MARK: -

	func clearEdit() {
		printDebug(.dEdit, " CLEAR   \(currentEdit?.packedZone?.zoneName ?? "no zone")")
		currentEdit = nil

		clearOffset()
		fullResign()
		gSetMapWorkMode()
	}

	func cancel() {
		if  let    e = currentEdit,
			let zone = currentlyEditedZone {
			clearEdit()
			zone.grab()
			e.updateWidgetsForEndEdit()

			FOREGROUND(after: 0.001) { gRelayoutMaps() }
		}
	}

	func quickStopCurrentEdit() {
		if  let e = currentEdit {
			applyPreservingEdit {
				capture()
				e.packedZone?.grab()
			}
		}
	}

	func cancelEdit() {
		currentEdit?.updateWidgetsForEndEdit()
		clearEdit()
	}

	func stopCurrentEdit(forceCapture: Bool = false, andRedraw: Bool = true) {
		if  let    e = currentEdit, !gIsEditingStateChanging {
			let zone = e.packedZone

			capture(force: forceCapture)

			cancelEdit()
			zone?.grab()

			if  andRedraw {
				FOREGROUND(after: 0.001) { gRelayoutMaps() }
			}
		}
	}

	func capture(force: Bool = false) {
		if  let current = currentEdit, let text = current.textWidget?.text, (!gTextCapturing || force) {
			printDebug(.dEdit, " CAPTURE \(text)")
			current.captureText(text)
		}
	}

	// MARK: - selecting
	// MARK: -

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
	
	// MARK: - events
	// MARK: -

	func moveOut(_ iMoveOut: Bool) {
		let revealed = currentlyEditedZone?.isExpanded ?? false

		gTemporarilySetTextEditorHandlesArrows()   // done first, this timer is often not be needed, KLUDGE to fix a bug where arrow keys are ignored

		let editAtOffset: FloatClosure = { [self] iOffset in
			if  let grabbed = gSelecting.firstSortedGrab {
				gSelecting.ungrabAll()
				edit(grabbed, setOffset: iOffset, immediately: revealed)
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
				if  !reveal {
					editAtOffset(.zero)
				} else {
					gRelayoutMaps() {
						editAtOffset(.zero)
					}
				}
			}
		}
	}

	func editingOffset(_ atStart: Bool) -> CGFloat {
        return currentTextWidget?.offset(for: selectedRange, atStart) ?? .zero
    }

	func moveUp(_ up: Bool, stopEdit: Bool) {
        currentOffset = currentOffset ?? editingOffset(up)
        let         e = currentEdit // for the case where stopEdit is true

        if  stopEdit {
            applyPreservingOffset {
                capture()
                currentlyEditedZone?.grab()
            }
        }
        
        if  var original = e?.packedZone {
            gMapEditor.moveUp(up, [original], targeting: currentOffset) { kinds in
				gControllers.signalFor(multiple: kinds) { [self] in
					if  let widget = original.widget, widget.isHere {       // offset has changed
                        currentOffset = widget.textWidget?.offset(for: selectedRange, up)
                    }
                    
					if  let first = gSelecting.firstSortedGrab, stopEdit {
                        original  = first
                        
						if  original != currentlyEditedZone { // if move up (above) does nothing, ignore
                            edit(original)
                        } else {
                            currentEdit = e // restore after capture sets it to nil

                            gSelecting.ungrabAll()
							assignAsFirstResponder(e?.textWidget)
                        }
                    } // else widgets are wrong

                    FOREGROUND(after: 0.01) { [self] in
                        setCursor(at: currentOffset)
						gMapView?.setNeedsDisplay()
                    }
                }
            }
        }
    }

	func setCursor(at iOffset: CGFloat?) {
        gTextEditorHandlesArrows = false
        if  var           offset = iOffset,
            let             zone = currentlyEditedZone,
            let               to = currentTextWidget {
			var            point = CGPoint.zero
            point                = to.convert(point, from: nil)
			offset              += point.x - 3.0   // subtract half the average character width -> closer to user expectation
            let             name = zone.unwrappedName
            let         location = name.location(of: offset, using: currentFont)

			printDebug(.dEdit, " AT \(location)    \(name)")
            selectedRange = NSMakeRange(location, 0)
        }
    }
    
}
