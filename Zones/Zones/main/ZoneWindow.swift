//
//  ZoneWindow.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import Cocoa


class ZoneWindow: ZWindow {


    static var window: ZoneWindow?


    override func awakeFromNib() {
        super.awakeFromNib()

        ZoneWindow.window = self
    }


    override var acceptsFirstResponder: Bool { get { return true } }


    override func keyDown(with event: ZEvent) {
        if !gEditingManager.isEditing && !gEditingManager.handleEvent(event, isWindow: true) {
            super.keyDown(with: event)
        }
    }


    // MARK:- menu validation
    // MARK:-


    override func validateMenuItem(_ menuItem: ZMenuItem) -> Bool {
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


    @IBAction func displayPreferences     (_ sender: Any?) { settingsController?.displayViewFor(id: .Preferences) }
    @IBAction func displayHelp            (_ sender: Any?) { settingsController?.displayViewFor(id: .Help) }
    @IBAction func printHere              (_ sender: Any?) { gEditingManager.printHere() }
    @IBAction func genericMenuHandler(_ iItem: ZMenuItem?) { gEditingManager.handleMenuItem(iItem) }
    @IBAction func copy              (_ iItem: ZMenuItem?) { gEditingManager.copyToPaste() }
    @IBAction func cut               (_ iItem: ZMenuItem?) { gEditingManager.delete() }
    @IBAction func delete            (_ iItem: ZMenuItem?) { gEditingManager.delete() }
    @IBAction func paste             (_ iItem: ZMenuItem?) { gEditingManager.paste() }
    @IBAction func toggleSearch      (_ iItem: ZMenuItem?) { gEditingManager.find() }
    @IBAction func undo              (_ iItem: ZMenuItem?) { gUndoManager.undo() }
    @IBAction func redo              (_ iItem: ZMenuItem?) { gUndoManager.redo() }

}
