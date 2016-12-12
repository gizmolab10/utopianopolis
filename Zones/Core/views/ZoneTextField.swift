//
//  ZoneTextField.swift
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


class ZoneTextField: ZTextField, ZTextFieldDelegate {


    var monitor: Any?
    var widget: ZoneWidget!
    var _isTextEditing: Bool = false


    var isTextEditing: Bool {
        get { return _isTextEditing }
        set {
            if _isTextEditing != newValue {
                _isTextEditing = newValue
                let   zone = widget.widgetZone

                if !_isTextEditing {
                    selectionManager.currentlyEditingZone  = nil

                    selectionManager.grab(zone!)
                    removeMonitorAsync()
                } else {
                    selectionManager.currentlyEditingZone  = zone
                    selectionManager.currentlyGrabbedZones = []

                    #if os(OSX)
                    monitor = ZEvent.addLocalMonitorForEvents(matching: .keyDown, handler: {(event) -> ZEvent? in
                        if self.isTextEditing {
                            let   flags = event.modifierFlags
                            let isArrow = flags.contains(.numericPad) && flags.contains(.function)

                            if !isArrow {
                                editingManager.handleKey(event, isWindow: false)
                            }
                        }

                        return event
                    })
                    #endif
                }

                controllersManager.signal(zone?.parentZone, regarding: .data)
            }
        }
    }


    func setup() {
        font                   = widgetFont
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
            dispatchAsyncInForeground {
                selectionManager.fullResign()
                
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

        if  textCapturing     == false {
            if zone?.zoneName != text! {
                textCapturing  = true
                zone?.zoneName = text!

                zone?.maybeNeedMerge()
                operationsManager.sync {}
            }
        }
    }


#if os(OSX)

    // fix a bug where root zone is editing on launch
    override var acceptsFirstResponder: Bool { get { return operationsManager.isReady } }


    override func controlTextDidChange(_ obj: Notification) {
        widget.layoutTextField()
    }


    override func textDidEndEditing(_ notification: Notification) {
        resignFirstResponder()
    }

#elseif os(iOS)

    // fix a bug where root zone is editing on launch
    override var canBecomeFirstResponder: Bool { get { return operationsManager.isReady } }
    

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        resignFirstResponder()

        return true
    }

#endif
}
