//
//  ZTextManager.swift
//  Zones
//
//  Created by Jonathan Sand on 2/19/18.
//  Copyright © 2018 Zones. All rights reserved.
//

import Foundation


let gTextManager = ZTextManager()
var gEditedTextWidget: ZoneTextWidget? { return gTextManager.currentEdit?.textWidget }


var gIsEditingText: Bool {
    if  gUseNewTextManager {
        return gTextManager.currentEdit?.wrappedZone != nil
    } else {
        return gEditorView?.window?.firstResponder?.isKind(of: ZTextView.self) ?? false
    }
}


class ZWidgetWrapper: NSObject {
    var        wrappedZone:           Zone? = nil
    var       wrappedTrait:         ZTrait? = nil
    var       originalText:         String? = nil
    var         textWidget: ZoneTextWidget? { return widget?.textWidget }
    var             widget:     ZoneWidget? { return gWidgetsManager.widgetForZone(wrappedZone) }
    var isEditingHyperlink:            Bool { return wrappedTrait?.traitType == .eHyperlink }
    var     isEditingEmail:            Bool { return wrappedTrait?.traitType == .eEmail }


    var textToEdit: String {
        if  let    name = wrappedTrait?.text ?? wrappedZone?.unwrappedName, name != kNullLink {
            return name
        }

        return kNoName
    }


    var textWithSuffix: String {
        var   result = kNoName

        if  let zone = wrappedZone {
            result   = zone.unwrappedName
            var need = 0

            switch gCountsMode {
            case .fetchable: need = zone.indirectFetchableCount
            case .progeny:   need = zone.indirectFetchableCount + zone.progenyCount
            default:         return result
            }

            var suffix: String? = nil

            /////////////////////////////////////
            // add suffix for "show counts as" //
            /////////////////////////////////////

            if  gDebugShowIdentifiers && zone.record != nil {
                suffix = zone.recordName
            } else if (need > 1) && (!zone.showChildren || (gCountsMode == .progeny)) {
                suffix = String(describing: need)
            }

            if  let s = suffix {
                result.append("  (" + s + ")")
            }
        }

        return result
    }


    convenience init(_ iZRecord: ZRecord) {
        self.init()
        self.edit(iZRecord)
    }


    func updateText(isEditing: Bool = false) {
        textWidget?.text = isEditing ? textToEdit : textWithSuffix
    }


    func edit(_ iZRecord: ZRecord) {
        wrappedTrait   = iZRecord as? ZTrait
        wrappedZone        = iZRecord as? Zone ?? wrappedTrait?.ownerZone
        originalText     = textToEdit
        textWidget?.text = originalText
    }


    func clearEdit() {
        wrappedZone      = nil
        wrappedTrait = nil
    }


    func newCapture(_ iText: String?) -> ZRecord? {
        if  let  trait = wrappedTrait { // this takes logical priority
            trait.text = iText

            return trait
        } else if let zone = wrappedZone { // do not process if editing a trait, above
            zone.zoneName  = iText

            return zone
        }

        return nil
    }


    func disassembleText(_ iText: String) -> String? {
        let        components = iText.components(separatedBy: "  (")
        var newText:  String? = components[0]

        if  newText == kNoName || newText == kNullLink || newText == "" {
            newText  = nil
        }

        return newText
    }


    func assignAndSignal(_ iText: String?) {
        let captured = newCapture(iText)

        captured?.maybeNeedSave()
        self.signalFor(captured, regarding: .datum)
    }


    func assignTextAndSync(_ iText: String?) {
        if  let t = iText, var  zone = wrappedZone, t != kNoName {
            let              newText = disassembleText(t)
            gTextCapturing           = true

            if  let  tWidget = textWidget {
                let original = originalText
                prepareUndoForTextChange(kUndoManager) {
                    self.assignTextAndSync(original)
                    tWidget.updateGUI()
                }
            }

            assignAndSignal(newText)

            if  let    target = zone.bookmarkTarget {
                zone = target
            }

            for bookmark in zone.fetchedBookmarks {
                ZWidgetWrapper(bookmark).assignAndSignal(newText)
            }

            gTextCapturing = false

            redrawAndSync()
        }
    }


    func prepareUndoForTextChange(_ manager: UndoManager?,_ onUndo: @escaping Closure) {
        if  let text = textWidget?.text,
            text    != originalText {
            manager?.registerUndo(withTarget:self) { iUndoSelf in
                let                newText = iUndoSelf.textWidget?.text ?? ""
                iUndoSelf.textWidget?.text = iUndoSelf.originalText
                iUndoSelf.originalText     = newText

                onUndo()
            }
        }
    }
}


class ZTextManager: NSObject {


    var currentEdit: ZWidgetWrapper? = nil
    var isEditingStateChanging = false
    var currentlyEditingZone: Zone? { return currentEdit?.wrappedZone }


    func clearEdit() { currentEdit = nil }
    func fullResign() { assignAsFirstResponder (nil) } // ios broken
    func edit(_ zRecord: ZRecord) { currentEdit = ZWidgetWrapper(zRecord) }
    func updateText(inZone: Zone?, isEditing: Bool = false) { if let z = inZone { ZWidgetWrapper(z).updateText(isEditing: isEditing) } }


    func deferEditingStateChange() {
        isEditingStateChanging          = true

        FOREGROUND(after: 0.1) {
            self.isEditingStateChanging = false
        }
    }


    func capture(force: Bool = false) {
        if  let current = currentEdit, let text = current.textWidget?.text, current.originalText != text, (!gTextCapturing || force) {
            current.assignTextAndSync(text)
        }
    }


    func assign(_ iText: String?, to iZone: Zone?) {
        if  let zone = iZone {
            ZWidgetWrapper(zone).assignTextAndSync(iText)
        }
    }


    func prepareUndoForTextChange(_ manager: UndoManager?,_ onUndo: @escaping Closure) {
        currentEdit?.prepareUndoForTextChange(manager, onUndo)
    }

}
