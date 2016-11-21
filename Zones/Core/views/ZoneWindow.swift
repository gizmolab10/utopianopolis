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




class ZoneWindow: NSWindow {


    static var window: ZoneWindow?
    override var acceptsFirstResponder: Bool { get { return true } }


    override func awakeFromNib() {
        super.awakeFromNib()

        ZoneWindow.window = self
    }


    override func keyDown(with event: ZEvent) {
        if selectionManager.currentlyEditingZone != nil || !handleKey(event) {
            super.keyDown(with: event)
        }
    }


    @discardableResult func handleKey(_ event: ZEvent) -> Bool {
        let isOption = event.modifierFlags.contains(.option)

        if isOption {
            if let widget = widgetsManager.currentMovableWidget {
                if let string = event.charactersIgnoringModifiers {
                    let key   = string[string.startIndex].description

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
                        editingManager.addZoneTo(widget.widgetZone)

                        break
                    case "\u{7F}":
                        editingManager.delete()

                        break
                    case "\r":
                        widget.textField.toggleResponderState()

                        break
                    default:
                        break
                    }
                }
            }
        }

        return isOption
    }
}
