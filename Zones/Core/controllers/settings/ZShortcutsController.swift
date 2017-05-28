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
        for value in [18, 38, 52, 83] {
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
        "   \tB\tcreates bookmark",
        "   \tF\tfind in cloud",
        "   \tP\tprints the graph",
        "   \tR\treverses order",
        "   \t-\tadd horizontal line",
        "   \tSPACE\tadds a child zone",
        "   \tDELETE\tdeletes zone",
        "   \tRETURN\tbegins editing",
        "   \t   +\tCOMMAND deselects",
        "   \t/\tfocuses on selected zone",
        "   \t   +\tCOMMAND adds to favorites",
        "   \tTAB\tadds a sibling zone",
        "   \t   +\tOPTION sibling enclosing",
        "   \t'\tshows next favorite",
        "   \t   +\tCOMMAND refocuses",
        "   \t\"\tshows previous favorite",
        "   \t   +\tOPTION shows favorites",
        "",
        "when editing a zone's text",
        "   \tRETURN\tends editing",
        "   \tTAB\tcreates sibling",
        "   \tCONTROL + SPACE creates child",
    ]
}
