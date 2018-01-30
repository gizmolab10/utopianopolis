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


    var tabStops = [NSTextTab]()


    override func setup() {
        controllerID = .shortcuts

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
        " ALWAYS:",
        "    \tRETURN   \tbegins or ends typing",
        "    \tTAB      \tnext idea",
        "",
        " WHILE TYPING:",
        "    \t     A   \tselect all text",
        "    \tCONTROL + SPACE  new idea",
        "    \tCOMMAND + (text is selected):",
        "    \t     L   \tlowercase",
        "    \t     U   \tuppercase",
        "",
        " WHILE NOT TYPING:",
        "    \tARROWS   \tnavigate within graph",
        "    \tDELETE   \tselected idea",
        "    \tSPACE    \tnew idea",
        "    \tA        \tselect all ideas",
        "    \tB        \tbookmark",
        "    \tC        \trecenter the graph",
        "    \tD        \tduplicate",
        "    \tE        \tcreate or edit email",
        "    \tF        \tfind in cloud",
        "    \tH        \tcreate or edit hyperlink",
        "    \tL        \tlowercase",
        "    \tO        \tsort by length",
        "    \tP        \tprints the graph",
        "    \tR        \treverses order",
        "    \tS        \tselect favorite =~ focus",
        "    \tU        \tuppercase",
        "    \t=        \tuse hyperlink",
        "    \t-        \tadds line, or [un]titles it",
        "    \t/        \tfocuses or toggles favorite",
        "    \t;        \tfocus on previous favorite",
        "    \t'        \tfocus on next favorite",
        "    \t.        \tnew ideas follow",
        "    \t,        \tnew ideas precede",
        "    \t$        \t(un)prefix with ($)",
        "    \t!        \t(un)prefix with (!)",
        "",
        "   OPTION:",
        "    \tARROWS   \trelocate selected idea",
        "    \tDELETE   \tretaining subordinate ideas",
        "    \tTAB      \tadds an idea containing",
        "    \tO        \tsort backwards by length",
        "",
        "   COMMAND:",
        "    \tARROWS   \textend all the way",
        "    \tRETURN   \tdeselects",
        "    \t/        \trefocuses current favorite",
        "",
        "   SHIFT + ARROW:",
        "    \tRIGHT    \treveals subordinates",
        "    \tLEFT     \thides subordinates",
        "    \tvertical \textends selection",
        "",
        "   SHIFT + MOUSE CLICK:",
        "    \t         \textends selection",
        "",
    ]
}
