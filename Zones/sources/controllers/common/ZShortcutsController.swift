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


enum ZShortcutType: String {
    case bold      = "b"
    case underline = "u"
}


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
        let                type = ZShortcutType(rawValue: raw.substring(with: NSMakeRange(0, 1)))
        let      paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = tabStops
        var          attributes = [NSParagraphStyleAttributeName: paragraphStyle as Any]

        switch type {
        case .bold?:
            let   font = ZFont.boldSystemFont(ofSize: ZFont.systemFontSize())
            attributes = [NSParagraphStyleAttributeName: paragraphStyle, NSFontAttributeName: font]
        case .underline?:
            attributes = [NSParagraphStyleAttributeName: paragraphStyle, NSUnderlineStyleAttributeName: 1]
        default:
            break
        }

        return NSAttributedString(string: text, attributes: attributes)
    }


    let shortcutStrings: [String] = [
        "",
        "b ALWAYS:",
        "u    KEY",
        "     \tRETURN   \tbegin or end typing",
        "     \tTAB      \tnext idea",
        "",
        "u    KEY + <CONTROL>",
        "     \tCOMMA    \tnext ideas precede",
        "     \tPERIOD   \tnext ideas follow",
        "     \tSPACE    \tnew idea",
        "",
        "b WHILE EDITING AN IDEA:",
        "u    KEY + <COMMAND>",
        "     \tA        \tselect all text",
        "",
        "b WHILE EDITING & TEXT IS SELECTED:",
        "u    KEY + <COMMAND>",
        "     \tL        \tlowercase",
        "     \tU        \tuppercase",
        "     \tD        \tcreate child with text",
        "",
        "b WHILE NOT EDITING AN IDEA:",
        "u    KEY",
        "     \tARROWS   \tnavigate within graph",
        "     \tDELETE   \tselected idea",
        "     \tCOMMA    \tnew ideas precede",
        "     \tPERIOD   \tnew ideas follow",
        "     \tSPACE    \tnew idea",
        "     \t/        \tfocus or toggle favorite",
        "     \t;        \tprevious favorite",
        "     \t'        \tnext favorite",
        "     \t[        \tgo back to prior focus",
        "     \t]        \tgo forward, opposite of [",
        "     \t-        \tadd line, or [un]title it",
        "     \t`        \tswitch to other graph",
        "     \t=        \tuse hyperlink or email",
        "     \t(marker) \t" + kMarkingCharacters,
        "     \tA        \tselect all ideas",
        "     \tB        \tcreate a bookmark",
        "     \tC        \trecenter the graph",
        "     \tD        \tduplicate",
        "     \tE        \tcreate or edit email",
        "     \tF        \tfind in cloud",
        "     \tH        \tcreate or edit hyperlink",
        "     \tI        \tcolor the text",
        "     \tJ        \timport from Thoughtful file",
        "     \tK        \texport to a Thoughtful file",
        "     \tL        \tconvert to lowercase",
        "     \tM        \trefetch from cloud",
        "     \tN        \talphabetize",
        "     \tO        \tsort by length",
        "     \tP        \tprint the graph",
        "     \tR        \treverse order",
        "     \tS        \tselect favorite =~ focus",
        "     \tU        \tconvert to uppercase",
        "",
        "u    KEY + <OPTION>",
        "     \tARROWS   \trelocate selected idea",
        "     \tDELETE   \tretaining children",
        "     \tTAB      \tnew idea containing",
        "     \tN        \talphabetize backwards",
        "     \tO        \tsort backwards by length",
        "",
        "u    KEY + <COMMAND>",
        "     \tARROWS   \textend all the way",
        "     \tRETURN   \tdeselect",
        "     \t/        \trefocus current favorite",
        "",
        "u    KEY + <COMMAND> + <OPTION>",
        "     \tDELETE   \tpermanently (not into trash)",
        "     \tO        \tshow data files in Finder",
        "",
        "u    ARROW KEY + <SHIFT>",
        "     \tRIGHT    \treveal children",
        "     \tLEFT     \thide children",
        "     \tUP DOWN  \textend selection",
        "",
        "u    MOUSE CLICK + <SHIFT>",
        "     \t+/- DRAG \t[un]extend selection",
        "",
    ]
}
