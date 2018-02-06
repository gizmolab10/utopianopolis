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

        for value in [15, 73] {
            tabStops.append(NSTextTab(textAlignment: .left, location: CGFloat(value), options: [:]))
        }
    }


    // MARK:- shortcuts table
    // MARK:-


    override func numberOfRows(in tableView: ZTableView) -> Int {
        return shortcutStrings.count
    }


    func tableView(_ tableView: ZTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let                text = shortcutStrings[row]
        let                next = text.substring(with: NSMakeRange(1, 1))
        let      paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = tabStops
        var          underlines = 0

        if text.starts(with: kSpace) && next.lowercased().isAlphabetical && next.uppercased() == next {
            underlines = 1
        }

        return NSAttributedString(string: text, attributes: [NSParagraphStyleAttributeName: paragraphStyle, NSUnderlineStyleAttributeName: underlines])
    }


    let shortcutStrings: [String] = [
        "",
        " ALWAYS:",
        "    \tRETURN   \tbegin or end typing",
        "    \tTAB      \tnext idea",
        "",
        "  KEY + CONTROL",
        "    \tCOMMA    \tnew ideas precede",
        "    \tPERIOD   \tnew ideas follow",
        "    \tSPACE    \tnew idea",
        "",
        " WHILE TYPING:",
        "  KEY + COMMAND",
        "    \tA        \tselect all text",
        "",
        " WHILE TYPING & TEXT IS SELECTED:",
        "  KEY + COMMAND",
        "    \tL        \tlowercase",
        "    \tU        \tuppercase",
        "    \tD        \tcreate child with text",
        "",
        " WHILE NOT TYPING:",
        "    \tARROWS   \tnavigate within graph",
        "    \tDELETE   \tselected idea",
        "    \tCOMMA    \tnew ideas precede",
        "    \tPERIOD   \tnew ideas follow",
        "    \tSPACE    \tnew idea",
        "    \tA        \tselect all ideas",
        "    \tB        \tcreate a bookmark",
        "    \tC        \trecenter the graph",
        "    \tD        \tduplicate",
        "    \tE        \tcreate or edit email",
        "    \tF        \tfind in cloud",
        "    \tH        \tcreate or edit hyperlink",
        "    \tI        \tcolor the text",
        "    \tL        \tconvert to lowercase",
        "    \tN        \talphabetize",
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
        "    \t[        \tgo back to prior focus",
        "    \t]        \tgo forward ... opposit of [",
        "    \t$        \t(un)prefix with ($)",
        "    \t!        \t(un)prefix with (!)",
        "    \t`        \tswitch to other graph",
        "",
        "  KEY + OPTION",
        "    \tARROWS   \trelocate selected idea",
        "    \tDELETE   \tretaining children",
        "    \tTAB      \tnew idea containing",
        "    \tN        \talphabetize backwards",
        "    \tO        \tsort backwards by length",
        "",
        "  KEY + COMMAND",
        "    \tARROWS   \textend all the way",
        "    \tRETURN   \tdeselect",
        "    \t/        \trefocus current favorite",
        "",
        "  ARROW KEY + SHIFT",
        "    \tRIGHT    \treveal children",
        "    \tLEFT     \thide children",
        "    \tUP DOWN  \textend selection",
        "",
        "  MODIFIER KEY + MOUSE CLICK",
        "    \t         \ttoggle selection",
        "    \tSHIFT    \t[un]extend selection",
        "",
    ]
}
