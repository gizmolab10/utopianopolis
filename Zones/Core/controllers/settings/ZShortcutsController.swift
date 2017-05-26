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


class ZShortcutsController: ZGenericTableController {


    override func identifier() -> ZControllerID { return .shortuts }


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        let  here = gRemoteStoresManager.manifest(for: storageMode).hereZone

        gFavoritesManager.updateIndexFor(here) { object in
            gFavoritesManager.update()
            self.genericTableUpdate()
        }
    }


    // MARK:- shortcuts table
    // MARK:-


    override func numberOfRows(in tableView: ZTableView) -> Int {
        return shortcutStrings.count
    }


    func tableView(_ tableView: ZTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return shortcutStrings[row]
    }


    let shortcutStrings: [String] = [
        " ARROWS change selection",
        " +   OPTION moves selected zone",
        " +   SHIFT + RIGHT expands",
        "           + LEFT collapses",
        " +   COMMAND all the way",
        "",
        " when editing text",
        "     RETURN ends editing",
        "     TAB creates sibling",
        "     CONTROL SPACE creates child",
        "",
        " other KEYS",
        "     B creates bookmark",
        "     F find in cloud",
        "     P prints the graph",
        "     R reverses order",
        "     / focuses on selected zone",
        "     ' shows next favorite",
        "     \" shows previous favorite",
        "     TAB adds a sibling zone",
        "     SPACE adds a child zone",
        "     DELETE deletes zone",
        "     RETURN begins editing",
        "     OPTION \" shows favorites",
        "     OPTION TAB sibling containing",
        "     COMMAND ' refocuses",
        "     COMMAND / adds to favorites",
        "     COMMAND RETURN deselects",
    ]
}
