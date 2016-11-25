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
    var _isEditing: Bool = false


    var isEditing: Bool {
        get { return _isEditing }
        set {
            if _isEditing != newValue {
                _isEditing = newValue
                let   zone = widget.widgetZone

                if !_isEditing {
                    selectionManager.currentlyGrabbedZones = [zone!]
                    selectionManager.currentlyEditingZone  = nil

                    removeMonitorAsync()
                } else {
                    selectionManager.currentlyEditingZone  = zone
                    selectionManager.currentlyGrabbedZones = []

                    monitor = ZEvent.addLocalMonitorForEvents(matching: .keyDown, handler: {(event) -> NSEvent? in
                        if self.isEditing {
                            editingManager.handleKey(event, isWindow: false)
                        }

                        return event
                    })
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
        if isEditing {
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
        if let save = monitor {
            monitor = nil

            dispatchAsyncInForegroundAfter(0.001, closure: {
                ZEvent.removeMonitor(save)
            })
        }
    }


    @discardableResult override func resignFirstResponder() -> Bool {
        captureText()

        let result = super.resignFirstResponder()

        if result && isEditing {
            dispatchAsyncInForeground {
                selectionManager.fullResign()
                
                self.isEditing = false
            }
        }

        return result
    }


    @discardableResult override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()

        if result {
            isEditing = true
        }

        return result
    }


    func captureText() {
        if  textCapturing    == false {
            if widget.widgetZone.zoneName != text! {
                textCapturing = true
                widget.widgetZone.zoneName = text!
            }
        }
    }


#if os(OSX)

    // fix a bug where root zone is editing on launch
    override var acceptsFirstResponder: Bool { get { return operationsManager.isReady } }


    override func controlTextDidChange(_ obj: Notification) {
        widget.layoutTextField()
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
