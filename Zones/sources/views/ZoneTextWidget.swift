//
//  ZoneTextWidget.swift
//  Zones
//
//  Created by Jonathan Sand on 10/27/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneTextWidget: ZTextField, ZTextFieldDelegate {


    var     widgetZone:  Zone   { return widget.widgetZone }
    var  preferredFont:  ZFont  { return widgetZone.isInFavorites ? gFavoritesFont : gWidgetFont }
    var         widget:  ZoneWidget!
    var        monitor:  Any?
    var   originalText = ""
    var _isTextEditing = false


    var isTextEditing: Bool {
        get { return _isTextEditing }
        set {
            if _isTextEditing != newValue {
                _isTextEditing = newValue
                let       zone = widgetZone
                font           = preferredFont

                if !_isTextEditing {
                    let  grab = gSelectionManager.currentlyEditingZone == zone
                    textColor = zone.grabbedTextColor

                    removeMonitorAsync()
                    abortEditing()

                    if  !grab {
                        textColor                          = ZColor.black
                    } else {
                        gSelectionManager.clearEdit()

                        zone.grab()
                    }
                } else {
                    gSelectionManager.currentlyEditingZone = zone
                    textColor                              = ZColor.black
                    originalText                           = zone.zoneName ?? ""

                    gSelectionManager.deselectGrabs()
                    enableUndo()
                    updateText()
                    addMonitor()

                    #if os(iOS)
                        selectAllText()
                    #endif
                }
            }
        }
    }


    func setup() {
        delegate               = self
        isBordered             = false
        textAlignment          = .left
        backgroundColor        = gClearColor
        zlayer.backgroundColor = gClearColor.cgColor

        #if os(iOS)
            autocapitalizationType = .none
        #endif
    }


    func toggleResponderState() {
        if isTextEditing {
            resignFirstResponder()
        } else {
            becomeFirstResponder()
        }
    }


    deinit {
        removeMonitorAsync()

        widget = nil
    }


    @discardableResult override func resignFirstResponder() -> Bool {
        var result = false

        if !gSelectionManager.isEditingStateChanging {
            captureText(force: false)

            result = super.resignFirstResponder()

            if result && isTextEditing {
                gSelectionManager.clearGrab()

                FOREGROUND { // avoid state garbling
                    self.isTextEditing = false
                }
            }
        }

        return result
    }


    @discardableResult override func becomeFirstResponder() -> Bool {
        var result = false

        if !gSelectionManager.isEditingStateChanging {
            result = super.becomeFirstResponder()

            if result {
                gSelectionManager.deferEditingStateChange()

                isTextEditing = true
            }
        }

        return result
    }


    func selectCharacter(in range: NSRange) {
        #if os(OSX)
        if let textInput = currentEditor() {
            textInput.selectedRange = range
        }
        #endif
    }


    func updateText() {
        let  zone = widgetZone
        text      = zone.unwrappedName
        var count = 0

        switch gCountsMode {
        case .fetchable: count = zone.fetchableCount
        case .progeny:   count = zone.fetchableCount + zone.progenyCount
        default:         return
        }

        if (count > 1) && !isTextEditing && (!zone.showChildren || (gCountsMode == .progeny)) {
            text?.append("  (\(count))")
        }
    }


    func alterCase(up: Bool) {
        if  var t = text {
            t = up ? t.uppercased() : t.lowercased()

            assign(t, to: widgetZone)
            updateGUI()
        }
    }
    

    func prepareUndoForTextChange(_ manager: UndoManager?,_ onUndo: @escaping Closure) {
        if originalText != text {
            manager?.registerUndo(withTarget:self) { iUndoSelf in
                let            newText = iUndoSelf.text ?? ""
                iUndoSelf        .text = iUndoSelf.originalText
                iUndoSelf.originalText = newText

                onUndo()
            }
        }
    }


    func updateGUI() {
        widget.layoutTextField()
        widget.setNeedsDisplay()
    }


    func assign(_ iText: String?, to iZone: Zone?) {
        if  let t = iText, let zone = iZone {
            gTextCapturing          = true

            let        assignTextTo = { (iTarget: Zone?) in
                if  let      target = iTarget {
                    let  components = t.components(separatedBy: "  (")
                    target.zoneName = components[0]
                }
            }

            prepareUndoForTextChange(gUndoManager) {
                self.captureText(force: true)
                self.updateGUI()
            }

            assignTextTo(zone)

            if  zone.isBookmark, let link = zone.crossLink, let mode = link.storageMode, let target = gRemoteStoresManager.cloudManagerFor(mode).zoneForRecordID(link.record.recordID) {
                assignTextTo(target)
            }

            for bookmark in gRemoteStoresManager.bookmarksFor(zone) {
                assignTextTo(bookmark)
                signalFor(bookmark, regarding: .datum)
            }
            
            redrawAndSync() {
                gTextCapturing = false
            }
        }
    }


    func captureText(force: Bool) {
        let zone = widgetZone

        if !gTextCapturing || force, zone.zoneName != text! {
            assign(text, to: zone)
        }
    }


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        let             zone = widgetZone

        if  zone.isBookmark, !zone.isGrabbed, !isTextEditing {
            var         rect = dirtyRect.insetBy(dx: 3.0, dy: 0.0)
            rect.size.height = 0.0
            rect.size.width -= 4.0
            rect.origin.y    = dirtyRect.maxY - 1.0
            let path         = ZBezierPath(rect: rect)
            path  .lineWidth = 0.7

            zone.color.setStroke()
            path.stroke()
        }

    }
}
