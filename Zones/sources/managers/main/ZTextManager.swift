//
//  ZTextManager.swift
//  Zones
//
//  Created by Jonathan Sand on 2/19/18.
//  Copyright © 2018 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import AppKit
#elseif os(iOS)
import UIKit
#endif


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


    var displayType: String {
        if  let        trait = packedTrait {
            return     trait.displayType
        } else if let  zone = packedZone {
            return     zone.displayType
        }

        return kNoValue
    }


    var unwrappedName: String {
        if  let        trait = packedTrait {
            return     trait.unwrappedName
        } else if let  zone = packedZone {
            return     zone.unwrappedName
        }

        return kNoValue
    }


    var textWithSuffix: String {
        var   result = displayType

        if  let zone = packedZone {
            result   = zone.unwrappedName
            var need = 0

            switch gCountsMode {
            case .fetchable: need = zone.indirectCount
            case .progeny:   need = zone.indirectCount + zone.progenyCount
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
        textWidget?.text = isEditing ? unwrappedName : textWithSuffix
    }


    func edit(_ iZRecord: ZRecord) {
        packedTrait      = iZRecord as? ZTrait
        packedZone       = iZRecord as? Zone ?? packedTrait?.ownerZone
        originalText     = unwrappedName
        textWidget?.text = originalText
    }


    func isEditing(_ iZRecord: ZRecord) -> Bool {
        return packedZone == iZRecord || packedTrait == iZRecord
    }


    func updateWidgetsForEndEdit() {
        if let t = textWidget {
            t.abortEditing() // NOTE: this does NOT remove selection highlight !!!!!!!
            t.deselectAllText()
            t.updateTextColor()
            t.layoutText()
        }

        widget?.setNeedsDisplay()
        packedZone?.grab()
    }


    func capture(_ iText: String?) {
        let text           = iText == displayType ? nil : iText

        if  let     trait  = packedTrait {      // traits take logical priority
            trait.ownerZone?.setTraitText(text, for: trait.traitType)
        } else if let zone = packedZone {       // ignore zone if editing a trait, above
            zone.recordsManager?.unregisterName(of: zone)

            zone.zoneName  = text

            zone.recordsManager?.registerName(of: zone)
            zone.maybeNeedSave()
        }
    }


    func removeSuffix(from iText: String?) -> String? {
        var newText: String? = nil

        if  let components = iText?.components(separatedBy: "  (") {
            newText        = components[0]

            if  newText == displayType || newText == kNullLink || newText == "" {
                newText  = nil
            }
        }

        return newText
    }


    func captureTextAndUpdateWidgets(_ iText: String?) {
        capture(iText)
        updateWidgetsForEndEdit()
    }


    func captureTextAndSync(_ iText: String?) {
        if  (originalText != iText || originalText == displayType) {
            let               newText = removeSuffix(from: iText)
            gTextCapturing            = true

            if  let                 t = textWidget {
                let          original = originalText
                prepareUndoForTextChange(kUndoManager) {
                    self.originalText = t.text

                    self.captureTextAndSync(original)
                    t.updateGUI()
                }
            }

            captureTextAndUpdateWidgets(newText)

            if  packedTrait == nil, // only if zone name is being edited
                var zone = packedZone {
                if  let    target = zone.bookmarkTarget {
                    zone = target

                    ZTextPack(target).captureTextAndUpdateWidgets(newText)
                }

                for bookmark in zone.fetchedBookmarks {
                    ZTextPack(bookmark).captureTextAndUpdateWidgets(newText)
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


class ZTextManager: ZTextView {

    
    var currentEdit: ZTextPack? = nil
    var isEditingStateChanging = false
    var currentlyEditingZone: Zone? { return currentEdit?.packedZone }
    var currentFont: ZFont { return currentlyEditingZone?.widget?.textWidget.font ?? gWidgetFont }
    var atEnd:   Bool { return selectedRange().lowerBound == currentlyEditingZone?.zoneName?.length }
    var atStart: Bool { return selectedRange().upperBound == 0 }


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
            let pack = ZTextPack(zRecord)
            if  pack.packedZone?.isWritableByUseer ?? false,
                let     textWidget = pack.textWidget,
                textWidget.window != nil {
                currentEdit        = pack

                pack.updateText(isEditing: true)
                gSelectionManager.deselectGrabs()
                textWidget.enableUndo()
                textWidget.layoutTextField()
                textWidget.becomeFirstResponder()
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
            current.captureTextAndSync(text)
        }
    }


    func assign(_ iText: String?, to iZone: Zone?) {
        if  let zone = iZone {
            ZTextPack(zone).captureTextAndSync(iText)
        }
    }


    func prepareUndoForTextChange(_ manager: UndoManager?,_ onUndo: @escaping Closure) {
        currentEdit?.prepareUndoForTextChange(manager, onUndo)
    }

    
    // MARK:- arrow and return keys
    // MARK:-
    

    override func doCommand(by selector: Selector) {
        switch selector {
        case #selector(insertNewline): stopCurrentEdit()
        default:                       super.doCommand(by: selector)
        }
    }
    
    
    @IBAction func genericMenuHandler(_ iItem: NSMenuItem?) {
        if  gWorkMode == .graphMode {
            gEditingManager.handleMenuItem(iItem)
        }
    }
    
    
    func handleArrow(_ arrow: ZArrowKey, flags: ZEventFlags) {
        let  isOption = flags.isOption
        
        switch arrow {
        case .up,
             .down:  stopEditAndMoveUp(arrow == .up)
        case .left:  if isOption { moveWordBackward(self) } else if atStart { stopEditAndMoveOut(true)  } else { moveLeft (self) }
        case .right: if isOption { moveWordForward (self) } else if atEnd   { stopEditAndMoveOut(false) } else { moveRight(self) }
        }
    }
    
    
    func stopEditAndMoveOut(_ iMoveOut: Bool) {
        if  iMoveOut {
            stopCurrentEdit()
            gEditingManager.moveOut {
                self.edit(gSelectionManager.currentMoveable)
                self.setCursor(at: 100000000.0)
            }
        } else if currentlyEditingZone?.children.count ?? 0 > 0 {
            stopCurrentEdit()
            gEditingManager.moveInto {
                self.edit(gSelectionManager.currentMoveable)
                self.setCursor(at: 0.0)
            }
        }
    }
    

    func stopEditAndMoveUp(_ iMoveUp: Bool) {
        let midRange = selectedRange()
        let endOfStart = midRange.lowerBound
        let startRange = NSMakeRange(0, endOfStart)
        let name = currentlyEditingZone?.zoneName ?? ""
        let midSelection = name.substring(with: midRange)
        let startSelection = name.substring(with: startRange)
        let font = currentFont
        let midWidth = midSelection.sizeWithFont(font).width
        let startWidth = startSelection.sizeWithFont(font).width
        var offset = startWidth + (iMoveUp ? 0.0 : midWidth)
        let level = currentlyEditingZone?.level ?? 0
        
        stopCurrentEdit()
        gEditingManager.moveUp(iMoveUp)
        edit(gSelectionManager.currentMoveable)
        
        if  level > (currentlyEditingZone?.level ?? 0) {
            offset += name.sizeWithFont(font).width
        }
        
        setCursor(at: offset)
    }

    
    func setCursor(at offset: CGFloat) {
        let name = currentlyEditingZone?.zoneName ?? ""
        let range = name.range(at: offset, with: currentFont)

        setSelectedRange(range)
    }
    
}
