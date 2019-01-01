//
//  ZShortcutsController.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 4/13/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
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


var gShortcuts: ZShortcutsController? { return gControllers.controllerForID(.shortcuts) as? ZShortcutsController }


class ZShortcutsController: ZGenericTableController {


    var tabStops = [NSTextTab]()


    override func viewDidLoad() {
        super.viewDidLoad()

        controllerID = .shortcuts

        for value in [20, 85, 290, 310, 375, 580, 600, 665] {
            tabStops.append(NSTextTab(textAlignment: .left, location: CGFloat(value), options: convertToNSTextTabOptionKeyDictionary([:])))
        }

        view.zlayer.backgroundColor = gBackgroundColor.cgColor
    }
    
    
    func handleEvent(_ iEvent: ZEvent) -> ZEvent? {
        if  let    key = iEvent.key {
            let COMMAND = iEvent.modifierFlags.isCommand
            switch key {
            case "?":              gGraphEditor.showHideKeyboardShortcuts()
            case "w": if COMMAND { gGraphEditor.showHideKeyboardShortcuts(hide: true) }
            default: break
            }
        }
        
        return nil
    }


    // MARK:- shortcuts table
    // MARK:-


    override func numberOfRows(in tableView: ZTableView) -> Int {
        return max(columnOne.count, max(columnTwo.count, columnThree.count))
    }
    
    
    func tableView(_ tableView: ZTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let      paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = tabStops
        let     attributed = attributedString(for: row, column: 0)

        attributed.append(   attributedString(for: row, column: 1))
        attributed.append(   attributedString(for: row, column: 2))
        attributed.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraph as Any, range: NSMakeRange(0, attributed.length))

        return attributed
    }
    
    
    func attributedString(for row: Int, column: Int) -> NSMutableAttributedString {
        let columnStrings = [columnOne, columnTwo, columnThree]
        let       strings = columnStrings[column]
        let           raw = row >= strings.count ? "" : strings[row]
        var          text = raw.substring(with: NSMakeRange(1, raw.length - 1))
        var    attributes = [String : Any] ()
        let          type = ZShortcutType(rawValue: raw.substring(with: NSMakeRange(0, 1)))
        let        prefix = text.substring(toExclusive: 4)

        if  text.length == 0 {
            text = "   \t         \t" // for empty lines, including after last row in first column array
        }
        
        switch type {
        case .bold?:
            let   bold = ZFont.boldSystemFont(ofSize: ZFont.systemFontSize)
            attributes = [NSAttributedString.Key.font.rawValue: bold as Any]
        case .underline?:
            text       = text.substring(fromInclusive: 4) // remove underline from leading spaces
            attributes = [NSAttributedString.Key.underlineStyle.rawValue: 1 as Any]
        default:
            break
        }

        var result = NSMutableAttributedString(string: text, attributes: convertToOptionalNSAttributedStringKeyDictionary(attributes))
        
        if  type  != nil && type! == .underline { // re-insert leading spaces
            let intermediate = NSMutableAttributedString(string: prefix)

            intermediate.append(result)

            result = intermediate
        }
        
        if  text.length < 8 && column != (columnStrings.count - 1) {
            result.append(NSAttributedString(string: "\t")) // KLUDGE to fix bug in first column where underlined "KEY" doesn't have enough subsequent tabs
        }

        result.append(NSAttributedString(string: "      \t"))
        
        return result
    }


    let columnOne: [String] = [
        "",
        "b                         ALWAYS:\t",
        "",
        "u    KEY",
        "     \tRETURN     \tbegin or end typing",
        "     \tTAB        \tcreate next idea",
        "",
        "u    COMMAND + KEY",
        "     \tCOMMA      \tshow or hide preferences",
        "",
        "u    COMMAND + SHIFT + KEY",
        "     \t/          \tshow or hide this window",
        "",
        "u    OPTION + KEY",
        "     \tCOMMA      \tconfine browsing to one idea",
        "     \tPERIOD     \tbrowse unconfined",
        "",
        "u    CONTROL + KEY",
        "     \tCOMMA      \tnext ideas precede",
        "     \tPERIOD     \tnext ideas follow",
        "     \tSPACE      \tcreate an idea",
        "",
        "",
        "b                WHILE EDITING TEXT:",
        "",
        "u    KEY",
        "     \tESCAPE     \tcancel edit, restore text",
        "",
        "u    COMMAND + KEY",
        "     \tPERIOD     \tcancel edit, restore text",
        "     \tA          \tselect all text",
        "",
        "",
        "b  WHILE EDITING AND TEXT IS SELECTED:",
        "",
        "u    COMMAND + SHIFT + KEY",
        "     \tD          \tcreate parent with text",
        "",
        "u    COMMAND + KEY",
        "     \t-          \tconvert text to or from titled line",
        "     \tD          \tcreate child with text",
        "     \tD          \tappend onto parent (if all selected)",
        "     \tL          \tlowercase",
        "     \tU          \tuppercase",
        "",
    ]


    let columnTwo: [String] = [
        "",
        "b                                     WHILE BROWSING (NOT EDITING TEXT):",
        "",
        "u    KEY",
        "     \tARROWS     \tnavigate within graph",
        "     \tDELETE     \tselected idea",
        "     \tCOMMA      \tcreated ideas precede",
        "     \tPERIOD     \tcreated ideas follow",
        "     \tSPACE      \tcreate an idea",
        "     \t/          \tfocus or toggle favorite",
        "     \t;          \tprevious favorite",
        "     \t'          \tnext favorite",
        "     \t[          \tgo back to prior focus",
        "     \t]          \tgo forward, opposite of [",
        "     \t-          \tadd line, or [un]title it",
        "     \t`          \tswitch to other graph",
        "     \t=          \tuse hyperlink or email",
        "     \tmark with: \t" + kMarkingCharacters,
        "     \tA          \tselect all ideas",
        "     \tB          \tcreate a bookmark",
        "     \tC          \trecenter the graph",
        "     \tD          \tduplicate",
        "     \tE          \tcreate or edit email",
        "     \tF          \tfind in cloud",
        "     \tH          \tcreate or edit hyperlink",
        "     \tI          \tcolor the text",
        "     \tJ          \timport from Thoughtful file",
        "     \tK          \texport to a Thoughtful file",
        "     \tL          \tconvert to lowercase",
        "     \tM          \trefetch children of selection",
        "     \tN          \talphabetize",
        "     \tO          \tsort by length",
        "     \tP          \tprint the graph",
        "     \tR          \treverse order",
        "     \tS          \tselect favorite equivalent to focus",
        "     \tT          \tswap selected idea with parent",
        "     \tU          \tconvert to uppercase",
        "",
        "u    SHIFT + MOUSE CLICK (with or without drag)",
        "     \t           \t[un]extend selection",
        "",
        ]
    
    
    let columnThree: [String] = [
        "",
        "",
        "",
        "u    SHIFT + OPTION + KEY",
        "     \tDELETE     \tconvert to titled line, retain children",
        "",
        "u    COMMAND + OPTION + KEY",
        "     \tDELETE     \tpermanently (not into trash)",
        "     \tO          \tshow data files in Finder",
        "",
        "u    SHIFT + ARROW KEY",
        "     \tRIGHT      \treveal children",
        "     \tLEFT       \thide children",
        "     \tUP DOWN    \textend selection",
        "",
        "u    COMMAND + KEY",
        "     \tARROWS     \textend all the way",
        "     \tRETURN     \tdeselect",
        "     \t/          \trefocus current favorite",
        "     \tD          \tappend onto parent",
        "     \tM          \trefetch entire graph",
        "",
        "u    OPTION + KEY",
        "     \tARROWS     \trelocate selected idea",
        "     \tDELETE     \tretaining children",
        "     \tTAB        \tnew idea containing",
        "     \tM          \trefetch entire subgraph of selection",
        "     \tN          \talphabetize backwards",
        "     \tO          \tsort backwards by length",
        "",
        "",
        "b        WHEN SEARCH BAR IS VISIBLE:",
        "",
        "u    KEY",
        "     \tRETURN     \tperform search",
        "     \tESCAPE     \tdismisss search bar",
        "",
        "u    COMMAND + KEY",
        "     \tA          \tselect all search text",
        "     \tF          \tdismisss search bar",
        "",
        "",
        "b     WHEN SEARCH RESULTS ARE VISIBLE:",
        "",
        "u    ARROW KEY",
        "     \tRIGHT      \tfocus on selected result",
        "",
    ]
    
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSTextTabOptionKeyDictionary(_ input: [String: Any]) -> [NSTextTab.OptionKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSTextTab.OptionKey(rawValue: key), value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}
