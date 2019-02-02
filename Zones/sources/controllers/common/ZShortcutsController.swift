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
    override var controllerID: ZControllerID { return .shortcuts }
    let bold = ZFont.boldSystemFont(ofSize: ZFont.systemFontSize)


    override func viewDidLoad() {
        super.viewDidLoad()
        
        var values: [Int] = []
        var offset = 0
        
        for _ in 0...3 {
            values.append(offset)
            values.append(offset + 20)
            values.append(offset + 85)
            
            offset += 290
        }

        for value in values {
            if value != 0 {
                tabStops.append(NSTextTab(textAlignment: .left, location: CGFloat(value), options: convertToNSTextTabOptionKeyDictionary([:])))
            }
        }

        view.zlayer.backgroundColor = gBackgroundColor.cgColor
    }
    
    
    func handleEvent(_ iEvent: ZEvent) -> ZEvent? {
        if  let    key = iEvent.key {
            let COMMAND = iEvent.modifierFlags.isCommand
            switch key {
            case "?", "/":         gGraphEditor.showHideKeyboardShortcuts()
            case "w": if COMMAND { gGraphEditor.showHideKeyboardShortcuts(hide: true) }
            case "p":              gShortcuts?.view.printView()

            default: break
            }
        }
        
        return nil
    }


    // MARK:- shortcuts table
    // MARK:-


    override func numberOfRows(in tableView: ZTableView) -> Int {
        return max(columnOne.count, max(columnTwo.count, max(columnThree.count, columnFour.count)))
    }
    
    
    func tableView(_ tableView: ZTableView, objectValueFor tableColumn: ZTableColumn?, row: Int) -> Any? {
        let      paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = tabStops
        let     attributed =  attributedString(for: row, column: 0)

        for column in 1...3 {
            attributed.append(attributedString(for: row, column: column))
        }

        attributed.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraph as Any, range: NSMakeRange(0, attributed.length))

        return attributed
    }
    
    
    func attributedString(for row: Int, column: Int) -> NSMutableAttributedString {
        let columnStrings = [columnOne, columnTwo, columnThree, columnFour]
        let       strings = columnStrings[column]
        let           raw = row >= strings.count ? "" : strings[row]
        let          type = ZShortcutType(rawValue: raw.substring(with: NSMakeRange(0, 1))) // grab first character
        var          text = raw.substring(with: NSMakeRange(1, raw.length - 1))             // grab remaining characters
        var    attributes = [String : Any] ()
        let        prefix = text.substring(toExclusive: 4)

        if  text.isEmpty {
            text = "   \t         \t" // for empty lines, including after last row in first column array
        }
        
        switch type {
        case .bold?:
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
        "u    COMMAND + OPTION + KEY",
        "     \t/          \tshow or hide this window",
        "",
        "u    COMMAND + KEY",
        "     \tCOMMA      \tshow or hide preferences",
        "     \tP          \tprint the graph (or this window)",
        "",
        "u    OPTION + KEY",
        "     \tCOMMA      \tconfine browsing to one idea",
        "     \tPERIOD     \tbrowse unconfined",
        "",
        "u    CONTROL + KEY",
        "     \tCOMMA      \tnext ideas precede",
        "     \tDELETE     \tshow trash",
        "     \tPERIOD     \tnext ideas follow",
        "     \tSPACE      \tcreate an idea",
        "",
        "",
        "b                WHILE EDITING TEXT:",
        "",
        "u    KEY",
        "     \tESCAPE     \tcancel edit, discarding changes",
        "",
        "u    COMMAND + KEY",
        "     \tPERIOD     \tcancel edit, discarding changes",
        "     \tA          \tselect all text",
        "",
        "u    CONTROL + KEY",
        "     \tCOMMA      \tnext ideas precede, move idea up",
        "     \tPERIOD     \tnext ideas follow, move idea down",
        "",
    ]
    
    
    let columnTwo: [String] = [
        "",
        "bWHILE EDITING AND TEXT IS SELECTED:",
        "",
        "u    COMMAND + OPTION + KEY",
        "     \tD          \tcreate parent with text",
        "",
        "u    COMMAND + KEY",
        "     \tHYPHEN     \tconvert text to or from titled line",
        "     \tD          \tcreate child with text",
        "     \tD          \tappend onto parent (if all selected)",
        "     \tL          \tlowercase",
        "     \tU          \tuppercase",
        "",
        "",
        "bWHEN SEARCH BAR IS VISIBLE:",
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
        "bWHEN SEARCH RESULTS ARE VISIBLE:",
        "",
        "u    ARROW KEY",
        "     \tRIGHT      \tfocus on selected result",
        "",
        "",
        "bWHILE SELECTING MULTIPLE IDEAS:",
        "",
        "u    KEY",
        "     \tHYPHEN     \tif first selected is line, -> parent",
        "     \tN          \talphabetize",
        "     \tO          \tsort by length",
        "     \t#          \tmark with ascending numbers",
        "",
    ]


    let columnThree: [String] = [
        "",
        "b                                  WHILE BROWSING (NOT EDITING TEXT):",
        "",
        "u    KEY",
        "     \tARROWS     \tnavigate within graph",
        "     \tCOMMA      \tnext ideas precede",
        "     \tDELETE     \tselected idea (and progeny)",
        "     \tHYPHEN     \tadd line, or [un]title it",
        "     \tPERIOD     \tnext ideas follow",
        "     \tSPACE      \tcreate an idea",
        "     \tmark with: \t" + kMarkingCharacters,
        "     \t/          \tbecome focus or manage favorite",
        "     \t;          \tprevious favorite",
        "     \t'          \tnext favorite",
        "     \t[          \t-> back to prior focus",
        "     \t]          \t-> forward, opposite of [",
        "     \t`          \tswitch to other graph",
        "     \t=          \tuse hyperlink or email",
        "     \tA          \tselect all ideas",
        "     \tB          \tcreate a bookmark",
        "     \tC          \trecenter the graph",
        "     \tD          \tduplicate",
        "     \tE          \tcreate or edit email",
        "     \tF          \tfind in cloud",
        "     \tH          \tcreate or edit hyperlink",
        "     \tI          \t[un]color the text",
        "     \tJ          \timport from Thoughtful file",
        "     \tK          \texport to a Thoughtful file",
        "     \tL          \t-> lowercase",
        "     \tM          \trefetch children of selection",
        "     \tP          \tprint the graph",
        "     \tR          \treverse order",
        "     \tT          \tswap selected idea with parent",
        "     \tU          \t-> uppercase",
    ]
    
    
    let columnFour: [String] = [
        "",
        "",
        "",
        "u    SHIFT + MOUSE CLICK (with or without drag)",
        "     \t           \t[un]extend selection",
        "",
        "u    COMMAND + OPTION + KEY",
        "     \tDELETE     \tpermanently (not into trash)",
        "     \tHYPHEN     \t-> to[from] titled line, retain children",
        "     \tO          \tshow data files in Finder",
        "",
        "u    SHIFT + ARROW KEY",
        "     \tRIGHT      \treveal children",
        "     \tLEFT       \thide children",
        "     \tvertical   \textend selection",
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
        "     \tRETURN     \tedit (with cursor at end)",
        "     \tTAB        \tnew idea containing",
        "     \tM          \trefetch entire subgraph of selection",
        "     \tN          \talphabetize backwards",
        "     \tO          \tsort backwards by length",
        "",
    ]

}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSTextTabOptionKeyDictionary(_ input: [String: Any]) -> [NSTextTab.OptionKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSTextTab.OptionKey(rawValue: key), value)})
}
