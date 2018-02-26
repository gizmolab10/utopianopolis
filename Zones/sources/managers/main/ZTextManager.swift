//
//  ZTextManager.swift
//  Zones
//
//  Created by Jonathan Sand on 2/19/18.
//  Copyright © 2018 Zones. All rights reserved.
//

import Foundation


let gTextManager = ZTextManager()
var gIsEditingText: Bool { return gTextManager.currentEdit != nil }
var gEditedTextWidget: ZoneTextWidget? { return gTextManager.currentEdit?.textWidget }


class ZTextPack: NSObject {
    var         packedZone:           Zone? = nil
    var        packedTrait:         ZTrait? = nil
    var       originalText:         String? = nil
    var         textWidget: ZoneTextWidget? { return widget?.textWidget }
    var             widget:     ZoneWidget? { return gWidgetsManager.widgetForZone(packedZone) }
    var isEditingHyperlink:            Bool { return packedTrait?.traitType == .eHyperlink }
    var     isEditingEmail:            Bool { return packedTrait?.traitType == .eEmail }


    var textToEdit: String {
        if  let        trait = packedTrait {
            if  let    tName = trait.text {
                return tName
            }
        } else if let  zone = packedZone {
            return     zone.unwrappedName
        }

        return kNoValue
    }


    var textWithSuffix: String {
        var   result = kNoValue

        if  let zone = packedZone {
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
        packedTrait     = iZRecord as? ZTrait
        packedZone      = iZRecord as? Zone ?? packedTrait?.ownerZone
        originalText     = textToEdit
        textWidget?.text = originalText
    }


    func isEditing(_ iZRecord: ZRecord) -> Bool {
        return packedZone == iZRecord || packedTrait == iZRecord
    }


    func updateWidgetsForEndEdit() {
        textWidget?.abortEditing() // NOTE: this does NOT remove selection highlight !!!!!!!
        textWidget?.deselectAllText()
        textWidget?.updateTextColor()
        textWidget?.layoutText()
        widget?.setNeedsDisplay()
        packedZone?.grab()
    }


    func capture(_ iText: String?) {
        let text           = iText == kNoValue ? nil : iText

        if  let     trait  = packedTrait {      // traits take logical priority
            trait.ownerZone?.setTraitText(text, for: trait.traitType)
        } else if let zone = packedZone {       // ignore zone if editing a trait, above
            zone.zoneName  = text

            zone.maybeNeedSave()
        }
    }


    func removeSuffix(from iText: String?) -> String? {
        var newText: String? = nil

        if  let components = iText?.components(separatedBy: "  (") {
            newText        = components[0]

            if  newText == kNoValue || newText == kNullLink || newText == "" {
                newText  = nil
            }
        }

        return newText
    }


    func assignAndSignal(_ iText: String?) {
        capture(iText)
        updateWidgetsForEndEdit()
        signalFor(packedZone, regarding: .datum)
    }


    func assignTextAndSync(_ iText: String?) {
        if  (originalText != iText || originalText == kNoValue) {
            let               newText = removeSuffix(from: iText)
            gTextCapturing            = true

            if  let           tWidget = textWidget {
                let          original = originalText
                prepareUndoForTextChange(kUndoManager) {
                    self.originalText = tWidget.text

                    self.assignTextAndSync(original)
                    tWidget.updateGUI()
                }
            }

            assignAndSignal(newText)

            if  packedTrait == nil, // only if zone name is being edited
                var zone = packedZone {
                if  let    target = zone.bookmarkTarget {
                    zone = target
                }

                for bookmark in zone.fetchedBookmarks {
                    ZTextPack(bookmark).assignAndSignal(newText)
                }
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


    var currentEdit: ZTextPack? = nil
    var isEditingStateChanging = false
    var currentlyEditingZone: Zone? { return currentEdit?.packedZone }


    func clearEdit() { currentEdit = nil }
    func fullResign() { assignAsFirstResponder (nil) } // ios broken


    func updateText(inZone: Zone?, isEditing: Bool = false) {
        if  let zone = inZone {
            ZTextPack(zone).updateText(isEditing: isEditing)
        }
    }

    
    func allowAsFirstResponder(_ iTextWidget: ZoneTextWidget) -> Bool {
        return !isEditingStateChanging && !iTextWidget.isFirstResponder && iTextWidget.widgetZone?.isWritableByUseer ?? false
    }


    func edit(_ zRecord: ZRecord) {
        if (currentEdit  == nil || !currentEdit!.isEditing(zRecord)) { // prevent infinite recursion inside becomeFirstResponder, called below
            let      pack = ZTextPack(zRecord)
            if  let     t = pack.textWidget,
                t.window != nil,
                pack.packedZone?.isWritableByUseer ?? false {
                currentEdit = pack

                pack.updateText(isEditing: true)
                gSelectionManager.deselectGrabs()
                t.enableUndo()
                t.layoutTextField()
                t.becomeFirstResponder()
                deferEditingStateChange()
            }
        }
    }


    func stopCurrentEdit(forceCapture: Bool = false) {
        if  let e = currentEdit, !isEditingStateChanging {
            capture(force: forceCapture)
            fullResign()
            clearEdit()
            e.updateWidgetsForEndEdit()
            e.packedZone?.grab()
        }
    }


    func deferEditingStateChange() {
        isEditingStateChanging          = true

        FOREGROUND(after: 0.1) {
            self.isEditingStateChanging = false
        }
    }


    func capture(force: Bool = false) {
        if  let current = currentEdit, let text = current.textWidget?.text, (!gTextCapturing || force) {
            current.assignTextAndSync(text)
        }
    }


    func assign(_ iText: String?, to iZone: Zone?) {
        if  let zone = iZone {
            ZTextPack(zone).assignTextAndSync(iText)
        }
    }


    func prepareUndoForTextChange(_ manager: UndoManager?,_ onUndo: @escaping Closure) {
        currentEdit?.prepareUndoForTextChange(manager, onUndo)
    }

}
