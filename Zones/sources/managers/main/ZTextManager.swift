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
        return gTextManager.currentEdit?.isEditing != nil
    } else {
        return gEditorView?.window?.firstResponder?.isKind(of: ZTextView.self) ?? false
    }
}


class ZEditPack: NSObject {
    var          isEditing:           Zone? = nil
    var     isEditingTrait:         ZTrait? = nil
    var       originalText:         String? = nil
    var         textWidget: ZoneTextWidget? { return widget?.textWidget }
    var             widget:     ZoneWidget? { return gWidgetsManager.widgetForZone(isEditing) }
    var isEditingHyperlink:            Bool { return isEditingTrait?.traitType == .eHyperlink }
    var     isEditingEmail:            Bool { return isEditingTrait?.traitType == .eEmail }


    var textToEdit: String {
        if  let    name = isEditingTrait?.text ?? isEditing?.unwrappedName, name != kNullLink {
            return name
        }

        return kNoName
    }


    convenience init(_ iZRecord: ZRecord) {
        self.init()
        self.edit(iZRecord)
    }


    func edit(_ iZRecord: ZRecord) {
        isEditingTrait   = iZRecord as? ZTrait
        isEditing        = iZRecord as? Zone ?? isEditingTrait?.ownerZone
        originalText     = textToEdit
        textWidget?.text = originalText
    }


    func clearEdit() {
        isEditing      = nil
        isEditingTrait = nil
    }


    func newCapture(_ iText: String?) -> ZRecord? {
        if  let  trait = isEditingTrait { // this takes logical priority
            trait.text = iText

            return trait
        } else if let zone = isEditing { // do not process if editing a trait, above
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
        if  let t = iText, var  zone = isEditing, t != kNoName {
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
                ZEditPack(bookmark).assignAndSignal(newText)
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


    var currentEdit: ZEditPack? = nil
    var isEditingStateChanging = false
    var currentlyEditingZone: Zone? { return currentEdit?.isEditing }


    func clearEdit() { currentEdit = nil }
    func fullResign() { assignAsFirstResponder (nil) } // ios broken
    func edit(_ zRecord: ZRecord) { currentEdit = ZEditPack(zRecord) }


    func deferEditingStateChange() {
        isEditingStateChanging          = true

        FOREGROUND(after: 0.1) {
            self.isEditingStateChanging = false
        }
    }


    func capture(force: Bool = false) {
        if  let pack = currentEdit, let text = pack.textWidget?.text, pack.originalText != text, (!gTextCapturing || force) {
            pack.assignTextAndSync(text)
        }
    }


    func assign(_ iText: String?, to iZone: Zone?) {
        if  let zone = iZone {
            ZEditPack(zone).assignTextAndSync(iText)
        }
    }


    func prepareUndoForTextChange(_ manager: UndoManager?,_ onUndo: @escaping Closure) {
        currentEdit?.prepareUndoForTextChange(manager, onUndo)
    }

}
