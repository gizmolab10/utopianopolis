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

        for value in [15, 73, 125] {
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
        "    \tRETURN   \tbegin or end typing",
        "    \tTAB      \tnext idea",
        "",
        " WHILE TYPING:",
        "    \tCONTROL + SPACE \tnew idea",
        "    \tCONTROL + .     \tnew ideas follow",
        "    \tCONTROL + ,     \tnew ideas precede",
        "    \tCOMMAND + A     \tselect all text",
        "    \tCOMMAND + (text is selected):",
        "    \t     L   \tlowercase",
        "    \t     U   \tuppercase",
        "    \t     D   \tcreate child with text",
        "",
        " WHILE NOT TYPING:",
        "    \tARROWS   \tnavigate within graph",
        "    \tDELETE   \tselected idea",
        "    \tSPACE    \tnew idea",
        "    \tA        \tselect all ideas",
        "    \tB        \tcreate a bookmark",
        "    \tC        \trecenter the graph",
        "    \tD        \tduplicate",
        "    \tE        \tcreate or edit email",
        "    \tF        \tfind in cloud",
        "    \tH        \tcreate or edit hyperlink",
        "    \tL        \tconvert to lowercase",
        "    \tO        \tsort by length",
        "    \tP        \tprint the graph",
        "    \tR        \treverse order",
        "    \tS        \tselect favorite =~ focus",
        "    \tU        \tconvert to uppercase",
        "    \t=        \tuse hyperlink",
        "    \t-        \tadd line, or [un]title it",
        "    \t/        \tfocus or toggle favorite",
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
        "    \tTAB      \tadd an idea containing",
        "    \tO        \tsort backwards by length",
        "",
        "   COMMAND:",
        "    \tARROWS   \textend all the way",
        "    \tRETURN   \tdeselect",
        "    \t/        \trefocus current favorite",
        "",
        "   SHIFT + ARROW:",
        "    \tRIGHT    \treveal subordinates",
        "    \tLEFT     \thide subordinates",
        "    \tvertical \textend selection",
        "",
        "   SHIFT + MOUSE CLICK:",
        "    \t         \textend selection",
        "",
    ]
}
