//
//  ZFavoritesController.swift
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


class ZFavoritesController: ZGenericTableController {


    override func identifier() -> ZControllerID { return .favorites }


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        let  here = gRemoteStoresManager.manifest(for: storageMode).hereZone

        gFavoritesManager.updateIndexFor(here) { object in
            gFavoritesManager.update()
            self.genericTableUpdate()
        }
    }


    // MARK:- favorites table
    // MARK:-


    override func numberOfRows(in tableView: ZTableView) -> Int {
        if  let    root = gFavoritesManager.rootZone {
            return root.count + 1
        }

        return 1
    }


    func tableView(_ tableView: ZTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        var        value = ""

        if  let     text = row == 0 ? "Edit ..." : gFavoritesManager.textAtIndex(row - 1) {
            let needsDot = gFavoritesManager.favoritesIndex == row - 1
            let   prefix = needsDot ? "•" : "  "
            value        = " \(prefix) \(text)"
        }

        return value
    }


    func actOnSelection(_ row: Int) {
        gSelectionManager.fullResign()

        if row == 0 {
            gStorageMode = .favorites

            gTravelManager.travel {
                self.signalFor(nil, regarding: .redraw)
            }
        } else if let favorite: Zone = gFavoritesManager.zoneAtIndex(row - 1) {
            gFavoritesManager.favoritesIndex = row - 1

            gTravelManager.travelThrough(favorite) { object, kind in
                if  let here = object as? Zone {
                    gHere    = here

                    gSelectionManager.deselect()
                    here.grab()
                    gControllersManager.syncToCloudAndSignalFor(here, regarding: kind) {}
                }
            }
        }
    }


    func tableView(_ tableView: ZTableView, shouldSelectRow row: Int) -> Bool {
        let select = gOperationsManager.isReady
        
        if  select {
            actOnSelection(row)
        }
        
        return false
    }
}
