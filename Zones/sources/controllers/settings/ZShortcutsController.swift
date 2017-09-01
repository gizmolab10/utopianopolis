//
//  ZShortcutsController.swift
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


    var              tabStops = [NSTextTab]()
    override var controllerID:  ZControllerID { return .shortcuts }


    override func awakeFromNib() {
        for value in [15, 73, 100] {
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
        " ALWAYS",
        "    \tRETURN   \tbegins or ends typing",
        "    \tTAB      \tadds an idea",
        "",
        " WHILE TYPING",
        "    \tCONTROL + SPACE  adds an idea",
        "    \tCOMMAND + TEXT IS SELECTED",
        "    \t     L   \tlowercase",
        "    \t     U   \tuppercase",
        "",
        " WHILE NOT TYPING",
        "    \tARROWS   \tnavigate within graph",
        "    \tDELETE   \tselected idea",
        "    \tSPACE    \tadds a subordinate idea",
        "    \tB        \tadds a bookmark",
        "    \tC        \trecenter the graph",
        "    \tF        \tfind in cloud",
        "    \tP        \tprints the graph",
        "    \tR        \treverses order",
        "    \t-    =   \tadds a [broken =] line",
        "    \t/        \tfocuses or toggles favorite",
        "    \t'        \tshows next favorite",
        "    \t;        \tshows previous favorite",
        "    \t.    ,   \tnew ideas follow, precede",
        "",
        "   OPTION",
        "    \tARROWS   \trelocate selected idea",
        "    \tDELETE   \tretaining subordinate ideas",
        "    \tTAB      \tadds an idea containing",
        "",
        "   COMMAND",
        "    \tARROWS   \textend all the way",
        "    \tRETURN   \tdeselects",
        "    \t/        \trefocuses current favorite",
        "",
        "   SHIFT + ARROW",
        "    \tRIGHT    \treveals subordinates",
        "    \tLEFT     \thides subordinates",
        "    \tvertical \textends selection",
        "",
        "   SHIFT + MOUSE CLICK",
        "    \t         \textends selection",
        "",
    ]
}
