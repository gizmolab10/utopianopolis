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


class ZFavoritesController: ZGenericController, ZTableViewDelegate, ZTableViewDataSource {

    
    @IBOutlet var favoritesTableHeight: NSLayoutConstraint?
    @IBOutlet var   favoritesTableView: ZTableView?


    override func identifier() -> ZControllerID { return .favorites }


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        if  let tableView = favoritesTableView {
            gFavoritesManager.updateIndexFor(gHere) { object in
                gFavoritesManager.update()
                tableView.reloadData()

                self.favoritesTableHeight?.constant = CGFloat((gFavoritesManager.count + 1) * 19)
            }
        }
    }


    // MARK:- favorites table
    // MARK:-


    func numberOfRows(in tableView: ZTableView) -> Int {
        var count = 1

        for zone in gFavoritesManager.favoritesRootZone.children {
            if zone.isBookmark {
                count += 1
            }
        }

        return count
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
        } else if let zone: Zone = gFavoritesManager.zoneAtIndex(row - 1) {
            gFavoritesManager.favoritesIndex = row - 1

            gEditingManager.focusOnZone(zone)
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
