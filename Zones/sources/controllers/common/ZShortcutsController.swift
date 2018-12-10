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


class ZShortcutsController: ZGenericTableController {


    var tabStops = [NSTextTab]()


    override func viewDidLoad() {
        super.viewDidLoad()

        controllerID = .shortcuts

        for value in [20, 90, 290, 310, 380, 580, 600, 670] {
            tabStops.append(NSTextTab(textAlignment: .left, location: CGFloat(value), options: convertToNSTextTabOptionKeyDictionary([:])))
        }

        view.zlayer.backgroundColor = gBackgroundColor.cgColor
    }


    // MARK:- shortcuts table
    // MARK:-


    override func numberOfRows(in tableView: ZTableView) -> Int {
        return max(columnOne.count, max(columnTwo.count, columnThree.count))
    }

    
//    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
//        let       raw = columnOne[row]
//        let actionKey = raw.substring(with: NSMakeRange(0, 1))
//
//        return "a".contains(actionKey)
//    }
    
    
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
        let  columnStrings = [columnOne, columnTwo, columnThree]
        let        strings = columnStrings[column]
        let            raw = row >= strings.count ? "" : strings[row]
        var           text = raw.substring(with: NSMakeRange(1, raw.length - 1))
        var     attributes = [String : Any] ()
        let           type = ZShortcutType(rawValue: raw.substring(with: NSMakeRange(0, 1)))
        let         prefix = text.substring(to: 4)

        if  text.length == 0 {
            text = "   \t         \t" // for empty lines, including after last row in first column array
        }
        
        switch type {
        case .bold?:
            let   bold = ZFont.boldSystemFont(ofSize: ZFont.systemFontSize)
            attributes = [NSAttributedString.Key.font.rawValue: bold as Any]
        case .underline?:
            text       = text.substring(from: 4)
            attributes = [NSAttributedString.Key.underlineStyle.rawValue: 1 as Any]
        default:
            break
        }

        var result = NSMutableAttributedString(string: text, attributes: convertToOptionalNSAttributedStringKeyDictionary(attributes))
        
        if  type  != nil && type! == .underline {
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
        "b ALWAYS:\t",
        "",
        "u    KEY",
        "     \tRETURN    \tbegin or end typing",
        "     \tTAB       \tcreate next idea",
        "",
        "u    CONTROL + KEY",
        "     \tCOMMA     \tnext ideas precede",
        "     \tPERIOD    \tnext ideas follow",
        "     \tSPACE     \tcreate an idea",
        "",
        "u    OPTION + KEY",
        "     \tCOMMA     \tconfine browsing to one idea",
        "     \tPERIOD    \tbrowse unconfined",
        "",
        "",
        "b WHILE EDITING TEXT:",
        "",
        "u    KEY",
        "     \tESCAPE    \tcancel edit, restore text",
        "",
        "u    COMMAND + KEY",
        "     \tPERIOD    \tcancel edit, restore text",
        "     \tA         \tselect all text",
        "",
        "",
        "b WHILE EDITING AND TEXT IS SELECTED:",
        "",
        "u    COMMAND + KEY",
        "     \tL         \tlowercase",
        "     \tU         \tuppercase",
        "     \tD         \tcreate child with text",
        "",
    ]


    let columnTwo: [String] = [
        "",
        "b WHILE BROWSING (NOT EDITING TEXT):",
        "",
        "u    KEY",
        "     \tARROWS    \tnavigate within graph",
        "     \tDELETE    \tselected idea",
        "     \tCOMMA     \tcreated ideas precede",
        "     \tPERIOD    \tcreated ideas follow",
        "     \tSPACE     \tcreate an idea",
        "     \t/         \tfocus or toggle favorite",
        "     \t;         \tprevious favorite",
        "     \t'         \tnext favorite",
        "     \t[         \tgo back to prior focus",
        "     \t]         \tgo forward, opposite of [",
        "     \t-         \tadd line, or [un]title it",
        "     \t`         \tswitch to other graph",
        "     \t=         \tuse hyperlink or email",
        "     \tmark with \t" + kMarkingCharacters,
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
        "     \tS        \tselect favorite equivalent to focus",
        "     \tU        \tconvert to uppercase",
        "",
        ]
    
    
    let columnThree: [String] = [
        "",
        "",
        "",
        "u    COMMAND + KEY",
        "     \tARROWS    \textend all the way",
        "     \tRETURN    \tdeselect",
        "     \t/         \trefocus current favorite",
        "",
        "u    OPTION + KEY",
        "     \tARROWS    \trelocate selected idea",
        "     \tDELETE    \tretaining children",
        "     \tTAB       \tnew idea containing",
        "     \tN         \talphabetize backwards",
        "     \tO         \tsort backwards by length",
        "",
        "u    COMMAND + OPTION + KEY",
        "     \tDELETE    \tpermanently (not into trash)",
        "     \tO         \tshow data files in Finder",
        "",
        "u    SHIFT + ARROW KEY",
        "     \tRIGHT     \treveal children",
        "     \tLEFT      \thide children",
        "     \tUP DOWN   \textend selection",
        "",
        "u    SHIFT + MOUSE CLICK (with or without drag)",
        "     \t          \t[un]extend selection",
        "",
        "",
        "b WHEN SEARCH BAR IS VISIBLE:",
        "",
        "u    KEY",
        "     \tRETURN    \tperform search",
        "     \tESCAPE    \tdismisss search bar",
        "",
        "u    COMMAND + KEY",
        "     \tA         \tselect all search text",
        "     \tF         \tdismisss search bar",
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
