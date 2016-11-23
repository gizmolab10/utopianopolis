//
//  ZoneWindow.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif




class ZoneWindow: ZWindow {


    static var window: ZoneWindow?
    override var acceptsFirstResponder: Bool { get { return true } }


    override func awakeFromNib() {
        super.awakeFromNib()

        ZoneWindow.window = self
    }


    override func keyDown(with event: ZEvent) {
        if selectionManager.currentlyEditingZone != nil || !handleKey(event, isWindow: true) {
            super.keyDown(with: event)
        }
    }


    @discardableResult func handleKey(_ event: ZEvent, isWindow: Bool) -> Bool {
        let     flags = event.modifierFlags
        let   isShift = flags.contains(.shift)
        let  isOption = flags.contains(.option)
        let isCommand = flags.contains(.command)
        let   isArrow = flags.contains(.numericPad) && flags.contains(.function)

        if let widget = widgetsManager.currentMovableWidget {
            if let string = event.charactersIgnoringModifiers {
                let key   = string[string.startIndex].description

                if isArrow {
                    let arrow = ZArrowKey(rawValue: key.utf8CString[2])!
                    var flags = ZKeyModifierFlags.none

                    if isShift   { flags.insert(.shift ) }
                    if isOption  { flags.insert(.option) }
                    if isCommand { flags.insert(.command) }

                    editingManager.move(arrow, modifierFlags: flags)
                } else {
                    switch key {
                    case "\t":
                        widget.textField.resignFirstResponder()

                        if let parent = widget.widgetZone.parentZone {
                            editingManager.addZoneTo(parent)
                        } else {
                            selectionManager.currentlyEditingZone = nil

                            controllersManager.updateToClosures(nil, regarding: .data)
                        }

                        break
                    case " ":
                        if isWindow {
                            editingManager.addZoneTo(widget.widgetZone)
                        }

                        break
                    case "\u{7F}":
                        if isWindow || isOption {
                            editingManager.delete()
                        }

                        break
                    case "\r":
                        if selectionManager.currentlyGrabbedZones.count != 0 {
                            selectionManager.currentlyGrabbedZones = []

                            widget.textField.becomeFirstResponder()
                        }
                        
                        break
                    default:
                        break
                    }
                }
            }
        }

        return isOption || isArrow
    }
}
