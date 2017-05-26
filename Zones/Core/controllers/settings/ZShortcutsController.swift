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
        "ARROWS change selection",
        "  +\tOPTION moves selected zone",
        "  +\tSHIFT\t+ RIGHT expands",
        "   \t \t  \t+ LEFT collapses",
        "  +\tCOMMAND all the way",
        "",
        "when editing text",
        "   \tRETURN ends editing",
        "   \tTAB creates sibling",
        "   \tCONTROL SPACE creates child",
        "",
        "other KEYS",
        "   \tB creates bookmark",
        "   \tF find in cloud",
        "   \tP prints the graph",
        "   \tR reverses order",
        "   \t/ focuses on selected zone",
        "   \t' shows next favorite",
        "   \t\" shows previous favorite",
        "   \tTAB adds a sibling zone",
        "   \tSPACE adds a child zone",
        "   \tDELETE deletes zone",
        "   \tRETURN begins editing",
        "   \tOPTION \" shows favorites",
        "   \tOPTION TAB sibling containing",
        "   \tCOMMAND ' refocuses",
        "   \tCOMMAND / adds to favorites",
        "   \tCOMMAND RETURN deselects",
    ]
}
