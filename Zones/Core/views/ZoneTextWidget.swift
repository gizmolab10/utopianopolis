//
//  ZoneTextWidget.swift
//  Zones
//
//  Created by Jonathan Sand on 10/27/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneTextWidget: ZTextField, ZTextFieldDelegate {


    var monitor: Any?
    var widget: ZoneWidget!
    var _isTextEditing  = false


    var isTextEditing: Bool {
        get { return _isTextEditing }
        set {
            if _isTextEditing != newValue {
                _isTextEditing = newValue
                let       zone = widget.widgetZone

                if !_isTextEditing {
                    let grab = gSelectionManager.currentlyEditingZone == zone

                    removeMonitorAsync()
                    abortEditing()

                    if grab {
                        gSelectionManager.currentlyEditingZone = nil

                        zone?.grab()
                    }
                } else {
                    gSelectionManager.currentlyEditingZone = zone
                    textColor                              = widget.widgetZone.isBookmark ? gGrabbedBookmarkColor : gGrabbedTextColor
                    font                                   = gSelectedWidgetFont

                    gSelectionManager.deselectGrabs()
                    updateText()
                    addMonitor()
                }

                signalFor(nil, regarding: .data)
            }
        }
    }


    func updateText() {
        let    name = widget.widgetZone.zoneName
        let hasName = name != nil
        text        = hasName ? name : "empty"
    }


    func setup() {
        delegate               = self
        isBordered             = false
        textAlignment          = .center
        backgroundColor        = ZColor.clear
        zlayer.backgroundColor = ZColor.clear.cgColor
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
        captureText()

        let result = super.resignFirstResponder()

        if result && isTextEditing {
            gSelectionManager.clearGrab()

            dispatchAsyncInForeground { // avoid state garbling
                self.isTextEditing = false
            }
        }

        return result
    }


    @discardableResult override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()

        if result {
            isTextEditing = true
        }

        return result
    }


    func captureText() {
        let zone = widget.widgetZone

        if  gTextCapturing    == false, zone != nil {
            if  zone!.zoneName != text! {
                gTextCapturing = true

                let assignText = { (toZone: Zone?) in
                    if  toZone != nil,     self.text != nil {
                        toZone!.zoneName = self.text!

                        toZone!.needUpdateSave()
                        toZone!.unmarkForStates([.needsMerge])
                    }
                }

//                UNDO(self) { iUndoSelf in
//                    iUndoSelf.text = priorName
//
//                    iUndoSelf.captureText()
//                }

                assignText(zone)

                if  zone!.isBookmark {
                    invokeWithMode(zone?.crossLink?.storageMode) {
                        if let target = gCloudManager.zoneForRecordID(zone?.crossLink?.record.recordID) {
                            assignText(target)
                        }
                    }
                }

                for bookmark in gCloudManager.bookmarksFor(zone) {
                    assignText(bookmark)
                }

                gOperationsManager.sync {}
            }
        }
    }
}
