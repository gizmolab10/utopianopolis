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
    var settingsController: ZSettingsViewController? { get { return gControllersManager.controllerForID(.settings) as? ZSettingsViewController }     }


    override func awakeFromNib() {
        super.awakeFromNib()

        ZoneWindow.window = self
    }

    #if os(OSX)
    override var acceptsFirstResponder: Bool { get { return true } }


    override func keyDown(with event: ZEvent) {
        if !gEditingManager.isEditing && !gEditingManager.handleEvent(event, isWindow: true) {
            super.keyDown(with: event)
        }
    }
    #endif


    // MARK:- menu delegation
    // MARK:-


    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        var valid = !gEditingManager.isEditing

        if valid {

            enum ZMenuType: Int {
                case Grab   = 1
                case Paste  = 2
                case Undo   = 3
                case Redo   = 4
            }

            let tag = menuItem.tag
            if  tag <= 4, tag > 0, let type = ZMenuType(rawValue: tag) {
                switch type {
                case .Grab:  valid = gSelectionManager.currentlyGrabbedZones.count != 0
                case .Paste: valid = gSelectionManager       .pasteableZones.count != 0
                case .Undo:  valid = gUndoManager.canUndo 
                case .Redo:  valid = gUndoManager.canRedo 
                }
            }
        }

        return valid
    }


    // MARK:- actions
    // MARK:-


    @IBAction func genericMenuHandler(_ iItem: NSMenuItem?) {
        var flags = (iItem?.keyEquivalentModifierMask)!
        let   key = (iItem?.keyEquivalent)!

        if key != key.lowercased() {
            flags.insert(.shift)    // add isShift to flags
        }

        gEditingManager.handleKey(key.lowercased(), flags: flags, isWindow: true)
    }


    @IBAction func displayPreferences(_ sender: Any?) { settingsController?.displayViewFor(id: .Preferences) }
    @IBAction func displayHelp       (_ sender: Any?) { settingsController?.displayViewFor(id: .Help) }
    @IBAction func printHere         (_ sender: Any?) { gEditingManager.printHere() }
    @IBAction func copy        (_ iItem: NSMenuItem?) { gEditingManager.copyToPaste() }
    @IBAction func cut         (_ iItem: NSMenuItem?) { gEditingManager.delete() }
    @IBAction func delete      (_ iItem: NSMenuItem?) { gEditingManager.delete() }
    @IBAction func paste       (_ iItem: NSMenuItem?) { gEditingManager.paste() }
    @IBAction func toggleSearch(_ iItem: NSMenuItem?) { gEditingManager.find() }
    @IBAction func undo        (_ iItem: NSMenuItem?) { gUndoManager.undo() }
    @IBAction func redo        (_ iItem: NSMenuItem?) { gUndoManager.redo() }

}
