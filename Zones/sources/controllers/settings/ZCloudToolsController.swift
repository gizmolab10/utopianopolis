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
        case eRecount
        case eZone
        case eConvert
        case eTrash
    }
    

    override func identifier() -> ZControllerID { return .cloudTools }
    override func numberOfRows(in tableView: ZTableView) -> Int { return 4 }


    func text(for kind: ZToolKind) -> String {
        switch kind {
        case .eRecount: return "Recount"
        case .eTrash:   return "Show Trash"
        case .eZone:    return "Restore Zone"
        case .eConvert: return "Convert to Booleans"
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
                case .eRecount: self.recount()
                case .eZone:    self.restoreZone()
                case .eTrash:   self.openTrashCan()
                case .eConvert: self.convertToBooleans()
                }
            }
        }

        return true
    }


    // MARK:- actions
    // MARK:-


    func openTrashCan() {
        gOperationsManager.fetchTrash() {
            if let count = gTrash?.count {
                self.columnarReport(" TRASH", "\(count)")
            }
        }
    }
    

    func recount() {
        gSelectionManager.rootMostMoveable.fullUpdateProgenyCount()
    }
    

    func convertToBooleans() {
        gOperationsManager.fetchAll() {
            self.redrawAndSync()
        }
    }


    func restoreZone() {
        // similar to gEditingManager.moveInto
        let zone = gSelectionManager.firstGrab

        if  let root = gRoot, !zone.isRoot {
            gHere    = root

            let closure = {
                zone.traverseAllProgeny { iChild in
                    iChild.isDeleted = false
                }

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
