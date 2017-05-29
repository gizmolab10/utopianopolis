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
        for value in [20, 38, 52, 72] {
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
        "while editing a zone's text",
        "     \tRETURN \tends editing",
        "     \tTAB    \tcreates sibling",
        "     \tSPACE+CONTROL creates child",
        "",
        "while not editing a zone",
        "     \tRETURN \tbegins editing",
        "     \tARROWS \tnavigate around",
        "     \tDELETE \tselected zone",
        "     \tSPACE  \tcreates child",
        "     \tTAB    \tcreates sibling",
        "     \tB  \tcreates bookmark",
        "     \tF  \tfind in cloud",
        "     \tP  \tprints the graph",
        "     \tR  \treverses order",
        "     \t-  \tadd horizontal line",
        "     \t/  \tfocuses on selected zone",
        "     \t'  \tshows next favorite",
        "     \t\" \tshows previous favorite",
        "",
        "SHIFT+ARROW keys",
        "     \tRIGHT  \texpands",
        "     \tLEFT   \tcollapses",
        "",
        "OPTION keys",
        "     \t\" \t  \tshows favorites",
        "     \tTAB \tcreates a sibling enclosing",
        "     \tARROWS \tmove selected zone",
        "",
        "COMMAND keys",
        "     \t/\tadd/remove favorite",
        "     \t'\trefocuses on current favorite",
        "     \tRETURN \tdeselects",
        "     \tARROWS \tall the way",
    ]
}
