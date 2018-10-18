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

        for value in [20, 90] {
            tabStops.append(NSTextTab(textAlignment: .left, location: CGFloat(value), options: [:]))
        }
        
        view.zlayer.backgroundColor = gBackgroundColor.cgColor
    }


    // MARK:- shortcuts table
    // MARK:-


    override func numberOfRows(in tableView: ZTableView) -> Int {
        return shortcutStrings.count
    }

    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let                 raw = shortcutStrings[row]
        let           actionKey = raw.substring(with: NSMakeRange(0, 1))
        
        return "a".contains(actionKey)
    }


    func tableView(_ tableView: ZTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let                 raw = shortcutStrings[row]
        let                text = raw.substring(with: NSMakeRange(1, raw.length - 1))
        let                next = raw.substring(with: NSMakeRange(2, 3))
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
        "  ALWAYS:",
        "a    \tRETURN   \tbegin or end typing",
        "a    \tTAB      \tnext idea",
        "",
        "   KEY + <CONTROL>",
        "a    \tCOMMA    \tnext ideas precede",
        "a    \tPERIOD   \tnext ideas follow",
        "a    \tSPACE    \tnew idea",
        "",
        "  WHILE EDITING AN IDEA:",
        "   KEY + <COMMAND>",
        "a    \tA        \tselect all text",
        "",
        "  WHILE EDITING & TEXT IS SELECTED:",
        "a  KEY + <COMMAND>",
        "a    \tL        \tlowercase",
        "a    \tU        \tuppercase",
        "a    \tD        \tcreate child with text",
        "",
        "  WHILE NOT EDITING AN IDEA:",
        "a    \tARROWS   \tnavigate within graph",
        "a    \tDELETE   \tselected idea",
        "a    \tCOMMA    \tnew ideas precede",
        "a    \tPERIOD   \tnew ideas follow",
        "a    \tSPACE    \tnew idea",
        "a    \t/        \tfocus or toggle favorite",
        "a    \t;        \tprevious favorite",
        "a    \t'        \tnext favorite",
        "a    \t[        \tgo back to prior focus",
        "a    \t]        \tgo forward, opposite of [",
        "a    \t-        \tadd line, or [un]title it",
        "a    \t`        \tswitch to other graph",
        "a    \t=        \tuse hyperlink or email",
        "a    \t(marker) \t" + kMarkingCharacters,
        "a    \tA        \tselect all ideas",
        "a    \tB        \tcreate a bookmark",
        "a    \tC        \trecenter the graph",
        "a    \tD        \tduplicate",
        "a    \tE        \tcreate or edit email",
        "a    \tF        \tfind in cloud",
        "a    \tH        \tcreate or edit hyperlink",
        "a    \tI        \tcolor the text",
        "a    \tJ        \timport from Thoughtful file",
        "a    \tK        \texport to a Thoughtful file",
        "a    \tL        \tconvert to lowercase",
        "a    \tM        \trefetch from cloud",
        "a    \tN        \talphabetize",
        "a    \tO        \tsort by length",
        "a    \tP        \tprint the graph",
        "a    \tR        \treverse order",
        "a    \tS        \tselect favorite =~ focus",
        "a    \tU        \tconvert to uppercase",
        "",
        "   KEY + <OPTION>",
        "a    \tARROWS   \trelocate selected idea",
        "a    \tDELETE   \tretaining children",
        "a    \tTAB      \tnew idea containing",
        "a    \tN        \talphabetize backwards",
        "a    \tO        \tsort backwards by length",
        "",
        "   KEY + <COMMAND>",
        "a    \tARROWS   \textend all the way",
        "a    \tRETURN   \tdeselect",
        "a    \t/        \trefocus current favorite",
        "",
        "   ARROW KEY + <SHIFT>",
        "a    \tRIGHT    \treveal children",
        "a    \tLEFT     \thide children",
        "a    \tUP DOWN  \textend selection",
        "",
        "   tMOUSE CLICK + <SHIFT>",
        "a    \t         \t[un]extend selection",
        "",
    ]
}
