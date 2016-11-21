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
        if selectionManager.currentlyEditingZone != nil || !handleKey(event) {
            super.keyDown(with: event)
        }
    }


    @discardableResult func handleKey(_ event: ZEvent) -> Bool {
        let    flags = event.modifierFlags
        let  isShift = flags.contains(.shift)
        let isOption = flags.contains(.option)
        let  isArrow = flags.contains(.numericPad) && flags.contains(.function)

        if let widget = widgetsManager.currentMovableWidget {
            if let string = event.charactersIgnoringModifiers {
                let key   = string[string.startIndex].description

                if isArrow {
                    let arrow = ZArrowKey(rawValue: key.utf8CString[2])!

                    switch arrow {
                    case .down:  editingManager       .moveDown(); break
                    case .up:    editingManager         .moveUp(); break
                    case .left:  editingManager   .moveToParent(); break
                    case .right: editingManager.moveIntoSibling(); break
                    }
                } else if isOption {
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
                        if selectionManager.currentlyEditingZone == nil {
                            selectionManager.currentlyGrabbedZones = []

                            widget.textField.becomeFirstResponder()
                            //                        } else {
                            //                            selectionManager.currentlyGrabbedZones = [widget.widgetZone]
                            //                            selectionManager.currentlyEditingZone  = nil
                            //
                            //                            widget.textField.resignFirstResponder()
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
