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


    enum ZToolKind: Int {
        case eUseCloud
        case eFullFetch
        case eIdentifiers
        case eAccess
        case eGather
        case eRecount
        case eRetry
        case eTrash
    }
    

    override func setup() {
        controllerID = .tools
    }


    override func numberOfRows(in tableView: ZTableView) -> Int {
        return !gIsSpecialUser ? 0 : 6 + (gIsLate ? 1 : 0)
    }


    func text(for kind: ZToolKind) -> String {
        switch kind {
        case .eUseCloud:    return          (gUseCloud ? "Use Cloud" : "Local File Only")
        case .eFullFetch:   return         (gFullFetch ? "Full"      : "Minimal") + " Fetch"
        case .eIdentifiers: return   (gShowIdentifiers ? "Visible"   : "Hidden")  + " Identifiers"
        case .eAccess:      return (gCrippleUserAccess ? "Crippled"  : "Normal")  + " User Access"
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
                case .eUseCloud:    self.toggleUseCloud()
                case .eFullFetch:   self.toggleFullFetch()
                case .eIdentifiers: self.toggleShowIdentifiers()
                case .eAccess:      self.toggleUserAccess()
                case .eRetry:       gDBOperationsManager.unHang()
                case .eTrash:       self.showTrashCan()
                case .eGather:      self.gatherAndShowLost()
                case .eRecount:     self.recount()
                }
            }
        }

        return true
    }


    // MARK:- actions
    // MARK:-


    func        toggleUseCloud() {          gUseCloud = !gUseCloud }
    func       toggleFullFetch() {         gFullFetch = !gFullFetch }
    func toggleShowIdentifiers() {   gShowIdentifiers = !gShowIdentifiers }
    func      toggleUserAccess() { gCrippleUserAccess = !gCrippleUserAccess }


    func showTrashCan() {
        if let trash = gTrash {
            gHere = trash

            gHere.needChildren()
            gDBOperationsManager.children(.restore) { iSame in
                self.redrawAndSync()
            }
        }
    }


    func gatherAndShowLost() {
        gDBOperationsManager.fetchLost {
            if  let lost = gLostAndFound {
                gHere    = lost

                self.columnarReport(" LOST", "\(lost.count)")

                lost.needChildren()
                lost.revealChildren()
                gDBOperationsManager.children(.all) { iSame in
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
        for dbID in gAllDatabaseIDs {
            let manager = gRemoteStoresManager.cloudManagerFor(dbID)
            manager        .hereZone.safeUpdateProgenyCount([])
            manager       .trashZone.safeUpdateProgenyCount([])
            manager.lostAndFoundZone.safeUpdateProgenyCount([])
        }

        syncToCloudAndSignalFor(nil, regarding: .redraw) {}
    }


    func restoreFromTrash() {
        gDBOperationsManager.undelete {
            self.signalFor(nil, regarding: .redraw)
        }

    }


    func emptyTrashButtonAction(_ button: NSButton) {

        // needs elaborate gui, like search results, but with checkboxes and [de]select all checkbox

        //gDBOperationsManager.emptyTrash {
        //    self.note("eliminated")
        //}
    }
}
