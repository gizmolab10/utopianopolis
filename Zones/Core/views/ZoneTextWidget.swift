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
                        gSelectionManager.currentlyEditingZone  = nil

                        zone?.grab()
                    }
                } else {
                    gSelectionManager.currentlyEditingZone  = zone
                    textColor                              = widget.widgetZone.isBookmark ? grabbedBookmarkColor : grabbedTextColor
                    font                                   = gGrabbedWidgetFont

                    gSelectionManager.clearGrab()

                    #if os(OSX)
                    monitor = ZEvent.addLocalMonitorForEvents(matching: .keyDown, handler: {(event) -> ZEvent? in
                        if self.isTextEditing, !event.modifierFlags.isNumericPad {
                            gEditingManager.handleEvent(event, isWindow: false)
                        }

                        return event
                    })
                    #endif
                }

                signalFor(nil, regarding: .data)
            }
        }
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


    func removeMonitorAsync() {
#if os(OSX)
        if let save = monitor {
            monitor = nil

            dispatchAsyncInForegroundAfter(0.001, closure: {
                ZEvent.removeMonitor(save)
            })
        }
#endif
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

                let assignText = { (iText: String?, toZone: Zone?) in
                    if toZone != nil, iText != nil {
                        toZone!.zoneName = iText!

                        toZone!.needUpdateSave()
                        toZone!.unmarkForStates([.needsMerge])
                    }
                }

//                UNDO(self) { iUndoSelf in
//                    iUndoSelf.text = priorName
//
//                    iUndoSelf.captureText()
//                }

                assignText(text, zone)

                if  zone!.isBookmark {
                    invokeWithMode(zone?.crossLink?.storageMode) {
                        if let target = gCloudManager.zoneForRecordID(zone?.crossLink?.record.recordID) {
                            assignText(text, target)
                        }
                    }
                }

                for bookmark in gCloudManager.bookmarksFor(zone) {
                    assignText(text, bookmark)
                }

                gOperationsManager.sync {}
            }
        }
    }


#if os(OSX)

    // fix a bug where root zone is editing on launch
    override var acceptsFirstResponder: Bool { get { return gOperationsManager.isReady } }


    override func controlTextDidChange(_ obj: Notification) {
        widget.layoutTextField()
    }


    override func textDidEndEditing(_ notification: Notification) {
        resignFirstResponder()

        if let value = notification.userInfo?["NSTextMovement"] as! NSNumber?, value == NSNumber(value: 17) {
            dispatchAsyncInForeground {
                gEditingManager.handleKey("\t", flags: ZEventFlags(), isWindow: true)
            }
        }
    }

#elseif os(iOS)

    // fix a bug where root zone is editing on launch
    override var canBecomeFirstResponder: Bool { get { return gOperationsManager.isReady } }
    

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        resignFirstResponder()

        return true
    }

#endif
}
