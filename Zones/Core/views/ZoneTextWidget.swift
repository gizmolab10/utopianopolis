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


    var  widget: ZoneWidget!
    var monitor:        Any?
    var    originalText = ""
    var _isTextEditing  = false


    var isTextEditing: Bool {
        get { return _isTextEditing }
        set {
            if _isTextEditing != newValue {
                let       zone = widget.widgetZone

                //signalFor(zone, regarding: .data)

                _isTextEditing = newValue

                if !_isTextEditing {
                    let  grab = gSelectionManager.currentlyEditingZone == zone
                    textColor = widget.widgetZone.isBookmark ? gGrabbedBookmarkColor : widget.widgetZone.grabbedTextColor

                    removeMonitorAsync()
                    abortEditing()

                    if  !grab {
                        textColor                              = ZColor.black
                    } else {
                        gSelectionManager.currentlyEditingZone = nil

                        zone?.grab()
                    }
                } else {
                    gSelectionManager.currentlyEditingZone = zone
                    font                                   = gSelectedWidgetFont
                    textColor                              = ZColor.black
                    originalText                           = zone?.zoneName ?? ""

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
        backgroundColor        = ZColor.clear
        zlayer.backgroundColor = ZColor.clear.cgColor

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

                dispatchAsyncInForeground { // avoid state garbling
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


    func updateText() {
        if  let  zone = widget.widgetZone {
            text      = zone.unwrappedName
            var count = 0

            switch gCountsMode {
            case .fetchable: count = zone.fetchableCount
            case .progeny:   count = zone.progenyCount - 1
            default:         return
            }

            if (count > 0) && !isTextEditing && (!zone.showChildren || (gCountsMode == .progeny)) {
                text  = text?.appending("  (\(count))")
            }
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
    

    func captureText(force: Bool) {
        if !gTextCapturing || force, let zone = widget.widgetZone, zone.zoneName != text! {
            gTextCapturing = true

            let      assignTextTo = { (iZone: Zone?) in
                if  let      zone = iZone, let components = self.text?.components(separatedBy: "  (") {
                    zone.zoneName = components[0]
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
}
