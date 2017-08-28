//
//  ZCloudToolsController.swift
//  Zones
//
//  Created by Jonathan Sand on 4/13/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZCloudToolsController: ZGenericTableController {


    enum ZToolKind: Int {
        case eZones
        case eTrash
        case eCenter
        case eGather
        case eRecount
    }
    

    override  var controllerID: ZControllerID { return .cloudTools }
    override func numberOfRows(in tableView: ZTableView) -> Int { return 3 }


    func text(for kind: ZToolKind) -> String {
        switch kind {
        case .eRecount: return "Recount"
        case .eCenter:  return "Bring to Center"
        case .eGather:  return "Gather Trash"
        case .eTrash:   return "Show Trash"
        case .eZones:   return "Restore Zones"
        }
    }


    func tableView(_ tableView: ZTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if  let kind = ZToolKind(rawValue: row) {
            return text(for: kind)
        }

        return ""
    }


    func tableView(_ tableView: ZTableView, shouldSelectRow row: Int) -> Bool {
        FOREGROUND { // put on next runloop cycle so button will instantly highlight
            tableView.deselectAll(self)

            if  let kind = ZToolKind(rawValue: row) {
                switch kind {
                case .eZones:   self.restoreZones()
                case .eTrash:   self.showTrashCan()
                case .eGather:  self.gatherAndShowTrash()
                case .eCenter:  self.recenter()
                case .eRecount: self.recount()
                }
            }
        }

        return true
    }


    // MARK:- actions
    // MARK:-


    func recenter() {
        gScaling      = 1.0
        gScrollOffset = CGPoint.zero

        gEditorController?.layoutForCurrentScrollOffset()
        gEditorView?.setNeedsDisplay()
    }


    func showTrashCan() {
        if let trash = gTrash {
            gHere = trash

            gHere.needChildren()
            gOperationsManager.children(.restore) {
                self.redrawAndSync()
            }
        }
    }

    func gatherAndShowTrash() {
        gOperationsManager.fetchTrash() {
            if let trash = gTrash {
                gHere = trash

                self.columnarReport(" TRASH", "\(trash.count)")

                trash.needProgeny()
                trash.displayChildren()
                gOperationsManager.children(.all) {
                    self.grabChildless()
                }
            }
        }
    }


    func grabChildless() {
        for child in gHere.children {
            if child.count == 0 {
                child.addToGrab()
            }
        }

        redrawAndSync()
    }


    func recount() {
        gSelectionManager.rootMostMoveable.fullUpdateProgenyCount()
    }


    func restoreZones() {
        for zone in gSelectionManager.currentGrabs {
            restoreZone(zone)
        }
    }


    func restoreZone(_ zone: Zone) {
        // similar to gEditingManager.moveInto
        let zone = gSelectionManager.firstGrab

        if  let root = gRoot, !zone.isRoot {
            gHere    = root

            let closure = {
                root.addAndReorderChild(zone, at: 0)
                self.redrawAndSync()
            }

            if zone.hasCompleteAncestorPath() && root.count > 0 {
                closure()
            } else {
                root.needChildren()
                root.displayChildren()
                gOperationsManager.children(.expand, 1) {
                    closure()
                }
            }
        }
    }


    func restoreFromTrash() {
        gOperationsManager.undelete {
            self.signalFor(nil, regarding: .redraw)
        }

    }


    func emptyTrashButtonAction(_ button: NSButton) {

        // needs elaborate gui, like search results, but with checkboxes and [de]select all checkbox

        //gOperationsManager.emptyTrash {
        //    self.note("eliminated")
        //}
    }
}
