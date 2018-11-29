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
var gEditedTextWidget: ZoneTextWidget? { return gTextManager.currentTextWidget }


class ZTextPack: NSObject {
    let          createdAt = Date()
    var         packedZone:           Zone?
    var        packedTrait:         ZTrait?
    var       originalText:         String?
    var         textWidget: ZoneTextWidget? { return widget?.textWidget }
    var             widget:     ZoneWidget? { return packedZone?.widget }
    var isEditingHyperlink:            Bool { return packedTrait?.traitType == .eHyperlink }
    var     isEditingEmail:            Bool { return packedTrait?.traitType == .eEmail }
    var   adequatelyPaused:            Bool { return Date().timeIntervalSince(createdAt) > 0.1 }


    var displayType: String {
        if  let        trait = packedTrait {
            return     trait.emptyName
        } else if let  zone = packedZone {
            return     zone.emptyName
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

            var suffix: String?

            /////////////////////////////////////
            // add suffix for "show counts as" //
            /////////////////////////////////////

            if  gDebugShowIdentifiers && zone.record != nil {
                suffix = zone.recordName
            } else if (need > 1) && (!zone.showingChildren || (gCountsMode == .progeny)) {
                suffix = String(describing: need)
            }

            if  let s = suffix {
                result.append("  (" + s + ")")
            }
        }

        return result
    }

    
    // MARK:- internals: editing zones and traits
    // MARK:-
    

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
        var newText: String?

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
        if  originalText             != iText {
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

    
    var currentOffset: CGFloat?
    var currentEdit: ZTextPack?
    var isEditingStateChanging = false
    var currentlyEditingZone: Zone? { return currentEdit?.packedZone }
    var currentTextWidget: ZoneTextWidget? { return currentlyEditingZone?.widget?.textWidget }
    var currentZoneName: String { return currentlyEditingZone?.zoneName ?? "" }
    var currentFont: ZFont { return currentTextWidget?.font ?? gWidgetFont }
    var atEnd:   Bool { return selectedRange().lowerBound == currentTextWidget?.text?.length ?? -1 }
    var atStart: Bool { return selectedRange().upperBound == 0 }

    
    // MARK:- editing
    // MARK:-
    

    func clearOffset() { currentOffset = nil }
    func clearEdit() { currentEdit = nil; clearOffset() }
    func fullResign() { assignAsFirstResponder (nil) } // ios broken


    func updateText(inZone: Zone?, isEditing: Bool = false) {
        if  let zone = inZone {
            ZTextPack(zone).updateText(isEditing: isEditing)
        }
    }

    
    func allowAsFirstResponder(_ iTextWidget: ZoneTextWidget) -> Bool {
        return !isEditingStateChanging && !iTextWidget.isFirstResponder && iTextWidget.widgetZone?.userCanWrite ?? false
    }


    func edit(_ zRecord: ZRecord) {
        if (currentEdit  == nil || !currentEdit!.isEditing(zRecord)) { // prevent infinite recursion inside becomeFirstResponder, called below
            let pack = ZTextPack(zRecord)
            if  pack.packedZone?.userCanWrite ?? false,
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
    
    
    func applyPreservingEdit(_ closure: Closure) {
        let e = currentEdit
        let o = currentOffset

        closure()
        
        currentEdit = e
        currentOffset = o
    }

    
    func quickStopCurrentEdit(clearOffset: Bool = false) {
        if  let e = currentEdit {
            applyPreservingEdit {
                capture()
                e.packedZone?.grab()
            }
        }
    }
    
    
    func stopCurrentEdit(forceCapture: Bool = false) {
        if  let e = currentEdit, !isEditingStateChanging {
            capture(force: forceCapture)
            clearEdit()
            fullResign()
            e.updateWidgetsForEndEdit()
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

    
    // MARK:- events
    // MARK:-
    

    override func doCommand(by selector: Selector) {
        switch selector {
        case #selector(insertNewline): stopCurrentEdit()
        case #selector(insertTab):     if currentEdit?.adequatelyPaused ?? false { gEditingManager.addNext() { iChild in iChild.edit() } } // stupid OSX issues tab twice (to create the new idea, then AFTERWARDS
        default:                       super.doCommand(by: selector)
        }
    }
    

    @IBAction func genericMenuHandler(_ iItem: NSMenuItem?) {
        if  gWorkMode == .graphMode {
            gEditingManager.handleMenuItem(iItem)
        }
    }
    
    
    // MARK:- arrow keys
    // MARK:-
    

    func handleArrow(_ arrow: ZArrowKey, flags: ZEventFlags) {
        let isCommand = flags.isCommand
        let  isOption = flags.isOption
        let   isShift = flags.isShift

        switch arrow {
        case .up,
             .down: stopEditAndMoveUp(arrow == .up)
        case .left:
            if  atStart {
                stopEditAndMoveOut(true)
            } else {
                clearOffset()
                
                if         isCommand && !isShift {
                    moveToBeginningOfLine(self)
                } else if  isCommand &&  isShift {
                    moveToBeginningOfLineAndModifySelection(self)
                } else if  isOption  &&  isShift {
                    moveWordLeftAndModifySelection(self)
                } else if !isOption  &&  isShift {
                    moveLeftAndModifySelection(self)
                } else if  isOption  && !isShift {
                    moveWordLeft(self)
                } else {
                    moveLeft(self)
                }
            }
        case .right:
            if atEnd {
                stopEditAndMoveOut(false)
            } else {
                clearOffset()
                
                if         isCommand && !isShift {
                    moveToEndOfLine(self)
                } else if  isCommand &&  isShift {
                    moveToEndOfLineAndModifySelection(self)
                } else if  isOption  &&  isShift {
                    moveWordRightAndModifySelection(self)
                } else if !isOption  &&  isShift {
                    moveRightAndModifySelection(self)
                } else if  isOption  && !isShift {
                    moveWordRight(self)
                } else {
                    moveRight(self)
                }
            }
        }
    }
    
    
    func stopEditAndMoveOut(_ iMoveOut: Bool) {
        if  iMoveOut {
            quickStopCurrentEdit(clearOffset: true)
            gEditingManager.moveOut {
                let grabbed = gSelectionManager.firstGrab

                gSelectionManager.clearGrab()
                gControllersManager.signalFor(nil, regarding: .relayout) {
                    FOREGROUND(after: 0.4) {
                        self.edit(grabbed)
                        self.setCursor(at: 100000000.0)
                    }
                }
            }
        } else if currentlyEditingZone?.children.count ?? 0 > 0 {
            quickStopCurrentEdit(clearOffset: true)
            gEditingManager.moveInto {
                self.edit(gSelectionManager.firstGrab)
                self.setCursor(at: 0.0)
            }
        }
    }
    

    func stopEditAndMoveUp(_ iMoveUp: Bool) {
        currentOffset = currentOffset ?? currentTextWidget?.offset(for: selectedRange(), iMoveUp)
        
        applyPreservingEdit {
            quickStopCurrentEdit()
            gEditingManager.moveUp(iMoveUp, targeting: currentOffset)
        }

        let zone  = gSelectionManager.firstGrab
        
        if  zone != currentlyEditingZone { // if move up (above) does nothing, ignore
            edit(zone)
            setCursor(at: currentOffset)
        }
    }
    
    
    func setCursor(at iOffset: CGFloat?) {
        if  var   offset = iOffset,
            let     zone = currentlyEditingZone,
            let       to = currentTextWidget {
            var    point = CGPoint(x: offset, y: 0.0)
            point        = to.convert(point, from: nil)
            offset       = point.x
            let     name = zone.unwrappedName
            let location = name.location(of: offset, using: currentFont)
            
            setSelectedRange(NSMakeRange(location, 0))
        }
    }
    
}
