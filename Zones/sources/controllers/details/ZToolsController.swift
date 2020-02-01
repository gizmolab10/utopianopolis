//
//  ZToolsController.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 4/13/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZToolsController: ZGenericTableController {

    
	override var controllerID: ZControllerID { return .idTools }


    enum ZToolKind: Int {
        case eRetry
        case eRecount
        case eAccess
		case eGather
		case eNames
		case eTrash
    }
    

    override func numberOfRows(in tableView: ZTableView) -> Int {
        return 0 + (gIsLate ? 1 : 0)
    }


    func text(for kind: ZToolKind) -> String {
		switch kind {
			case .eNames: 	return (gDebugMode.contains(.names)     ? "Visible"   : "Hidden")  + " Identifiers"
			case .eAccess:  return (gDebugMode.contains(.access) ? "Crippled"  : "Normal")  + " User Access"
			case .eGather:  return "Gather Lost and Found"
			case .eRetry:   return "Retry Cloud"
			case .eTrash:   return "Show Trash"
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
					case .eAccess:  ZDebugMode.toggle(.access)
					case .eNames: 	ZDebugMode.toggle(.names)
					case .eRetry:   gBatches.unHang()
					case .eTrash:   self.showTrashCan()
					case .eGather:  self.gatherAndShowLost()
					case .eRecount: gRemoteStorage.recount(); gControllers.signalAndSync(nil, regarding: .eRelayout) {}
				}
            }
        }

        return true
    }


    // MARK:- actions
    // MARK:-

    func showTrashCan() {
        if let trash = gTrash {
            gHere = trash

            gHere.needChildren()
			self.redrawAndSync()
        }
    }


    func gatherAndShowLost() {
        gBatches.fetchLost { iSame in
            if  let lost = gLostAndFound {
                gHere    = lost

                self.columnarReport(" LOST", "\(lost.count)")

                lost.needChildren()
                lost.revealChildren()
				self.grabChildless()
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
        gBatches.undelete { iSame in
            self.redrawGraph()
        }
    }

}
