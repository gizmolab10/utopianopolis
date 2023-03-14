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

            // //////////////////////////////////
            // add suffix for "show counts as" //
            // //////////////////////////////////

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

    // MARK: - internals: editing zones and traits
    // MARK: -

	convenience init(_ iZRecord: ZRecord) {
        self.init()
        self.setup(for: iZRecord)
    }

	func updateText(isEditing: Bool = false) {
		var          text = isEditing ? unwrappedName : textWithSuffix

		if  !isEditing,
		    let         w = widget {
			let  isLinear = w.isLinearMode
			let threshold = isLinear ? 18 : 20
			let      type = w.widgetType
			if  threshold < text.length,
				!type.contains(.tExemplar),
				!type.contains(.tMainMap) || !isLinear {                       // is in favorites or is circular
				let  isLine = text[0] == kHyphen
				text        = text.substring(toExclusive: isLinear ? isLine ? 20 : 15 : 10) // shorten to fit (in favorites map area or in circles)

				if !isLine {
					text.append(kEllipsis)
				}
			}
		}

		textWidget?.setText(text)
	}

    func setup(for iZRecord: ZRecord) {
		packedTrait  = iZRecord as? ZTrait                          // do this first
		packedZone   = iZRecord as? Zone ?? packedTrait?.ownerZone
        originalText = unwrappedName

		textWidget?.setText(originalText)
    }

    func isEditing(_ iZRecord: ZRecord) -> Bool {
        return packedZone == iZRecord || packedTrait == iZRecord
    }

    func updateWidgetsForEndEdit() {
		if  let z = packedZone,
			let w = gWidgets.widgetForZone(z),
			let t = w.textWidget {
			t.abortEditing()      // NOTE: this does NOT remove selection highlight
			t.deselectAllText()
			t.updateTextColor()
			t.updateText()
			w.linearGrandRelayout()
		}
    }

    func capture(_ iText: String?) {
		if  let text           = iText == emptyName ? nil : iText {
			if  let     trait  = packedTrait {                             // traits take logical priority
				trait.ownerZone?.setTraitText(text, for: trait.traitType)
			} else if let zone = packedZone {                              // ignore zone if editing a trait, above
				zone.setNameForSelfAndBookmarks(to: text.unescaped)
				zone.zRecords?.removeFromLocalSearchIndex(nameOf: zone)
				zone.addToLocalSearchIndex()
			}
		}
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

    func captureTextAndUpdateWidgets(_ iText: String?) {
        capture(iText)
        updateWidgetsForEndEdit()
    }

	func captureText(_ iText: String?, redrawSync: Bool = false) {
		if (iText == emptyName || iText == kEmpty) {
			if  let             type  = packedTrait?.traitType {
				packedZone?.removeTrait(for: type)                     // trait text was deleted (email, hyperlink)
			}
		} else if              iText != originalText {
            let              newText  = removeSuffix(from: iText)
            gTextCapturing            = true

            if  let                w  = textWidget {
                let         original  = originalText
                prepareUndoForTextChange(gUndoManager) { [self] in
                    originalText = w.text

					captureText(original, redrawSync: true)
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
			gRelayoutMaps()
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
                let            newText = iUndoSelf.textWidget?.text ?? kEmpty
				iUndoSelf.originalText = newText

				iUndoSelf.textWidget?.setText(iUndoSelf.originalText)
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
	var currentFont 	    : ZFont           { return currentTextWidget?.font ?? gMainFont }
	var atEnd 	            : Bool            { return selectedRange.lowerBound == currentTextWidget?.text?.length ?? -1 }
	var atStart  	        : Bool            { return selectedRange.upperBound == 0 }

    // MARK: - editing
    // MARK: -

    func clearOffset() { currentOffset = nil }

	func clearEdit() {
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
				pack.updateText(isEditing: true)            // updates drawnSize of textWidget
				gSelecting.ungrabAll(retaining: [zone])		// so crumbs will appear correctly
				gSetEditIdeaMode()

				if  let t = zone.widget?.textWidget {
					t.enableUndo()
					assignAsFirstResponder(t)
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
				gRelayoutMaps(for: zone)
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
            current.captureText(text, redrawSync: true)
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

	@IBAction func genericMenuHandler(_ iItem: ZMenuItem?) { gAppDelegate?.genericMenuHandler(iItem) }

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
			gMapEditor.moveInto { [self] reveal in
				if  !reveal {
					editAtOffset(.zero)
				} else {
					gRelayoutMaps(for: currentlyEditedZone) {
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
				gControllers.signalFor(nil, multiple: kinds) { [self] in
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
        if  var     offset = iOffset,
            let       zone = currentlyEditedZone,
            let         to = currentTextWidget {
			var      point = CGPoint.zero
            point          = to.convert(point, from: nil)
			offset        += point.x - 3.0   // subtract half the average character width -> closer to user expectation
            let       name = zone.unwrappedName
            let   location = name.location(of: offset, using: currentFont)

			printDebug(.dEdit, " AT \(location)    \(name)")
            selectedRange = NSMakeRange(location, 0)
        }
    }
    
}
