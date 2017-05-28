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


    var tabStops = [NSTextTab]()


    override func identifier() -> ZControllerID { return .shortuts }


    override func awakeFromNib() {
        for value in [18, 40, 52, 83] {
            tabStops.append(NSTextTab(textAlignment: .left, location: CGFloat(value), options: [:]))
        }
    }


    // MARK:- shortcuts table
    // MARK:-


    override func numberOfRows(in tableView: ZTableView) -> Int {
        return shortcutStrings.count
    }


    func tableView(_ tableView: ZTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let      style = NSMutableParagraphStyle()
        let       text = shortcutStrings[row]
        style.tabStops = tabStops

        return NSAttributedString(string: text, attributes: [NSParagraphStyleAttributeName: style])
    }


    let shortcutStrings: [String] = [
        "ARROWS navigate around",
        "  +\tOPTION moves selected zone",
        "  +\tSHIFT\t+ RIGHT expands",
        "   \t \t  \t+ LEFT collapses",
        "  +\tCOMMAND all the way",
        "",
        "other KEYS",
        "   \tB creates bookmark",
        "   \tF find in cloud",
        "   \tP prints the graph",
        "   \tR reverses order",
        "   \t- add horizontal line",
        "   \t/ focuses on selected zone",
        "   \t' shows next favorite",
        "   \t\" shows previous favorite",
        "   \tTAB adds a sibling zone",
        "   \tSPACE adds a child zone",
        "   \tDELETE deletes zone",
        "   \tRETURN begins editing",
        "   \tOPTION \" shows favorites",
        "   \tOPTION TAB sibling enclosing",
        "   \tCOMMAND ' refocuses",
        "   \tCOMMAND / adds to favorites",
        "   \tCOMMAND RETURN deselects",
        "",
        "when editing a zone's text",
        "   \tRETURN ends editing",
        "   \tTAB creates sibling",
        "   \tCONTROL SPACE creates child",
    ]
}
