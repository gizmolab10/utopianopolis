//
//  ZToolsController.swift
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


class ZToolsController: ZGenericTableController {

    
    override var backgroundColor: CGColor { return gDarkishBackgroundColor }


    enum ZToolKind: Int {
        case eRetry
        case eRecount
        case eAccess
        case eIdentifiers
        case eGather
        case eTrash
    }
    

    override func setup() {
        controllerID = .tools
    }


    override func numberOfRows(in tableView: ZTableView) -> Int {
        return 0 + (gIsLate ? 1 : 0)
    }


    func text(for kind: ZToolKind) -> String {
        switch kind {
        case .eIdentifiers: return (gDebugShowIdentifiers ? "Visible"   : "Hidden")  + " Identifiers"
        case .eAccess:      return (gDebugDenyUserAccess  ? "Crippled"  : "Normal")  + " User Access"
        case .eGather:      return "Gather Lost and Found"
        case .eRetry:       return "Retry Cloud"
        case .eTrash:       return "Show Trash"
        case .eRecount:     return "Recount"
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
                case .eIdentifiers: self.toggleShowIdentifiers()
                case .eAccess:      self.toggleUserAccess()
                case .eRetry:       gBatchManager.unHang()
                case .eTrash:       self.showTrashCan()
                case .eGather:      self.gatherAndShowLost()
                case .eRecount:     gRemoteStoresManager.recount(); gControllersManager.syncToCloudAfterSignalFor(nil, regarding: .relayout) {}
                }
            }
        }

        return true
    }


    // MARK:- actions
    // MARK:-


    func toggleShowIdentifiers() {   gDebugShowIdentifiers = !gDebugShowIdentifiers }
    func      toggleUserAccess() { gDebugDenyUserAccess = !gDebugDenyUserAccess }


    func showTrashCan() {
        if let trash = gTrash {
            gHere = trash

            gHere.needChildren()
            gBatchManager.children(.restore) { iSame in
                self.redrawAndSync()
            }
        }
    }


    func gatherAndShowLost() {
        gBatchManager.fetchLost { iSame in
            if  let lost = gLostAndFound {
                gHere    = lost

                self.columnarReport(" LOST", "\(lost.count)")

                lost.needChildren()
                lost.revealChildren()
                gBatchManager.children(.all) { iSame in
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


    func restoreFromTrash() {
        gBatchManager.undelete { iSame in
            gControllersManager.signalFor(nil, regarding: .relayout)
        }
    }

}
