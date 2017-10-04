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
        case eRetry
        case eTrash
        case eGather
        case eRecount
    }
    

    override var controllerID: ZControllerID { return .cloudTools }


    override func numberOfRows(in tableView: ZTableView) -> Int {
        return gIsLate ? 1 : 0
    }


    func text(for kind: ZToolKind) -> String {
        switch kind {
        case .eTrash:   return "Show Trash"
        case .eRetry:   return "Retry Cloud"
        case .eGather:  return "Gather Trash"
        case .eRecount: return "Recount"
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
                case .eRetry:   self.retryCloud()
                case .eTrash:   self.showTrashCan()
                case .eGather:  self.gatherAndShowTrash()
                case .eRecount: self.recount()
                }
            }
        }

        return true
    }


    // MARK:- actions
    // MARK:-


    func retryCloud() {
        gOperationsManager.cloudCallback?(0)
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
