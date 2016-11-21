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


    var widget: ZoneWidget!


    func setup() {
        font                   = widgetFont
        delegate               = self
        isBordered             = false
        textAlignment          = .center
        backgroundColor        = ZColor.clear
        zlayer.backgroundColor = ZColor.clear.cgColor
    }


    @discardableResult override func resignFirstResponder() -> Bool {
        selectionManager.currentlyEditingZone = nil

        captureText()

        return super.resignFirstResponder()
    }


    @discardableResult override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()

        if result {
            selectionManager.currentlyEditingZone = widget.widgetZone
        }

        return result
    }


    func captureText() {
        if  stateManager.textCapturing    == false {
            if widget.widgetZone.zoneName != text! {
                stateManager.textCapturing = true
                widget.widgetZone.zoneName = text!
            }
        }
    }
    


#if os(OSX)

    // fix a bug where root zone is editing on launch
    override var acceptsFirstResponder: Bool { get { return stateManager.isReady } }


    override func controlTextDidEndEditing(_ obj: Notification) {
        captureText()
        dispatchAsyncInForeground {
            self.resignFirstResponder()
            selectionManager.fullResign()
        }
    }


    func stopEditing() {
        if currentEditor() != nil {
            resignFirstResponder()
        }
    }


    override func controlTextDidChange(_ obj: Notification) {
        widget.layoutTextField()
    }

#elseif os(iOS)

    // fix a bug where root zone is editing on launch
    override var canBecomeFirstResponder: Bool { get { return stateManager.isReady } }
    

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        captureText()

        return true
    }


    func stopEditing() {
        resignFirstResponder()
    }

#endif
}
