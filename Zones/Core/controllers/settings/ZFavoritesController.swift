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
            return root.count
        }

        return 1
    }


    func tableView(_ tableView: ZTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if  let     zone = gFavoritesManager.zoneAtIndex(row),
            let     name = zone.zoneName {
            let needsDot = gFavoritesManager.favoritesIndex == row
            let   prefix = needsDot ? "•" : "  "
            let     text = " \(prefix) \(name)"

            if let color = name == "favorites" ? gBookmarkColor : zone.bookmarkTarget?.color {
                return NSAttributedString(string: text, attributes: [NSForegroundColorAttributeName: color])
            }

            return text
        }

        return ""
    }


    func tableView(_ tableView: ZTableView, shouldSelectRow row: Int) -> Bool {
        gSelectionManager.fullResign()

        if let favorite: Zone = gFavoritesManager.zoneAtIndex(row) {
            gFavoritesManager.favoritesIndex = row

            gTravelManager.travelThrough(favorite) { object, kind in
                if  let here = object as? Zone {
                    gHere    = here

                    gSelectionManager.deselect()
                    here.grab()
                    gControllersManager.syncToCloudAndSignalFor(nil, regarding: kind) {
                        self.signalFor(nil, regarding: .redraw)
                    }
                }
            }
        }

        return false
    }
}
