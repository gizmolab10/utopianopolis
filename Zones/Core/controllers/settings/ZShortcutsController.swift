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


    override func identifier() -> ZControllerID { return .shortcuts }


    override func awakeFromNib() {
        for value in [20, 72] {
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
        "",
        "  while or while not editing text",
        "     \tRETURN \tbegins/ends editing",
        "     \tTAB    \tnew sibling item",
        "",
        "  while editing text",
        "     \tCONTROL+SPACE  new item",
        "",
        "  while not editing text",
        "     \tARROWS \tnavigate within graph",
        "     \tDELETE \tselected item",
        "     \tSPACE  \tnew item",
        "     \tB      \tnew bookmark",
        "     \tF      \tfind in cloud",
        "     \tP      \tprints the graph",
        "     \tR      \treverses order",
        "     \t-      \tnew horizontal line",
        "     \t/      \tfocuses on selected item",
        "     \t'      \tshows next favorite",
        "     \t\"     \tshows previous favorite",
        "",
        "    SHIFT+ARROW key",
        "     \tRIGHT  \texpands",
        "     \tLEFT   \tcollapses",
        "",
        "    OPTION key",
        "     \tARROWS \trelocate selected item",
        "     \tDELETE \tretaining subordinate items",
        "     \tTAB    \tnew sibling containing",
        "",
        "    COMMAND key",
        "     \tARROWS \textend all the way",
        "     \tRETURN \tdeselects",
        "     \t/      \tadds/removes favorite",
        "     \t'      \trefocuses current favorite",
        "",
    ]
}
