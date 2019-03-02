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
    case append    = "+"
}


var gShortcuts: ZShortcutsController? { return gControllers.controllerForID(.shortcuts) as? ZShortcutsController }


class ZShortcutsController: ZGenericTableController {


    @IBOutlet var gridView: ZView?
    @IBOutlet var clipView: ZView?
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
        
        if let g = gridView {
            g.removeFromSuperview()
            clipView?.addSubview(g)

            g.snp.makeConstraints { make in
                make.top.bottom.left.right.equalTo(tableView)
            }
            
            g.zlayer.backgroundColor = CGColor.clear
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        
        if let g = gridView {
            for view in g.subviews {
                if  view.identifier?.rawValue == kLineView {
                    view.zlayer.backgroundColor = kLineColor
                }
            }
        }
    }
    
    
    func handleEvent(_ iEvent: ZEvent) -> ZEvent? {
        if  let    key = iEvent.key {
            let COMMAND = iEvent.modifierFlags.isCommand
            switch key {
            case "?", "/":         gGraphEditor.showHideKeyboardShortcuts()
            case "w": if COMMAND { gGraphEditor.showHideKeyboardShortcuts(hide: true) }
            case "r": if COMMAND { sendEmailBugReport() }
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
        var        prefix = "   "

        if  text.isEmpty {
            text = "   \t         \t" // for empty lines, including after last row
        }
        
        switch type {
        case .bold?:
            attributes = [NSAttributedString.Key.font.rawValue: bold as Any]
        case .append?, .underline?:
            attributes = [NSAttributedString.Key.underlineStyle.rawValue: 1 as Any]
            
            if type == .append {
                prefix += "+ "
            }
            
        default:
            prefix     = " "
            break
        }

        var result = NSMutableAttributedString(string: text, attributes: convertToOptionalNSAttributedStringKeyDictionary(attributes))
        let intermediate = NSMutableAttributedString(string: prefix)
        
        intermediate.append(result)
        
        result = intermediate

        if  text.length < 9 && row != 1 {
            result.append(NSAttributedString(string: "\t")) // KLUDGE to fix bug in first column where underlined "KEY" doesn't have enough subsequent tabs
        }

        result.append(NSAttributedString(string: "     \t"))

        return result
    }


    let columnOne: [String] = [
        "",
        "bALWAYS:\t",
        "",
        "uKEY",
        "     \tRETURN     \tbegin or end typing",
        "     \tTAB        \tcreate next idea",
        "",
        "+CONTROL",
        "     \tCOMMA      \ttoggle browsing: un/confined",
        "     \tDELETE     \tshow trash",
        "     \tPERIOD     \ttoggle next ideas precede/follow",
        "     \tSPACE      \tcreate an idea",
        "",
        "+COMMAND",
        "     \tCOMMA      \tshow or hide preferences",
        "     \tP          \tprint the graph (or this window)",
        "",
        "+COMMAND + OPTION",
        "     \tR          \treport a problem",
        "     \t/          \tshow or hide this window",
        "",
        "uCONTROL + COMMAND + OPTION",
        "     \t           \tshow or hide indicators",
        "",
        "",
        "",
        "",
        "",
        "bSEARCH BAR:",
        "",
        "uKEY",
        "     \tRETURN     \tperform search",
        "     \tESCAPE     \tdismisss search bar",
        "",
        "+COMMAND",
        "     \tA          \tselect all search text",
        "     \tF          \tdismisss search bar",
        "",
    ]

    
    let columnTwo: [String] = [
        "",
        "bEDITING TEXT:",
        "",
        "uKEY",
        "     \tESCAPE     \tcancel edit, discarding changes",
        "",
        "+COMMAND",
        "     \tPERIOD     \tcancel edit, discarding changes",
        "     \tA          \tselect all text",
        "",
        "+COMMAND + OPTION",
        "     \tPERIOD     \ttoggle next ideas precede/follow,",
        "                  \t(and) move idea up/down",
        "",
        "",
        "",
        "bEDITING, TEXT IS SELECTED:",
        "",
        "+COMMAND",
        "     \tHYPHEN     \tconvert text to or from 'titled line'",
        "     \tD          \tif all selected, append onto parent",
        "     \t           \tif not all selected, create as a child",
        "     \tL          \tlowercase",
        "     \tT          \tcreate parent with text",
        "     \tU          \tuppercase",
        "",
        "",
        "",
        "bSEARCH RESULTS:",
        "",
        "uKEY",
        "     \tRIGHT ARROW (or)",
        "     \tRETURN    \tfocus on selected result",
        "",
    ]
    

    let columnThree: [String] = [
        "",
        "bBROWSING (NOT EDITING TEXT):",
        "",
        "     \tmark with: \t" + kMarkingCharacters,
        "",
        "uKEY",
        "     \tARROWS     \tnavigate within graph",
        "     \tCOMMA      \ttoggle browsing: un/confined",
        "     \tDELETE     \tselected ideas and their progeny",
        "     \tHYPHEN     \tadd 'line', or [un]title it",
        "     \tPERIOD     \ttoggle next ideas precede/follow",
        "     \tSPACE      \tcreate an idea",
        "     \t/          \t[re]focus or manage favorite",
        "     \t\\         \tswitch to other graph",
        "     \t;          \t-> prior favorite",
        "     \t'          \t-> next favorite",
        "     \t[          \t-> prior focus",
        "     \t]          \t-> next focus",
        "     \t=          \tuse hyperlink or email",
        "     \tA          \tselect all ideas",
        "     \tB          \tcreate a bookmark",
        "     \tC          \trecenter the graph",
        "     \tD          \tduplicate",
        "     \tE          \tcreate or edit email",
        "     \tF          \tsearch",
        "     \tG          \trefetch children of selection",
        "     \tH          \tcreate or edit hyperlink",
        "     \tI          \t[un]color the text",
        "     \tL          \t-> lowercase",
        "     \tO          \timport from a Thoughtful file",
        "     \tP          \tprint the graph",
        "     \tR          \treverse order of children",
        "     \tS          \tsave to a Thoughtful file",
        "     \tT          \tswap selected idea with parent",
        "     \tU          \t-> uppercase",
        "",
    ]
    
    
    let columnFour: [String] = [
        "",
        "+OPTION",
        "     \tARROWS     \trelocate selected idea",
        "     \tDELETE     \tretaining children",
        "     \tRETURN     \tedit (with cursor at end)",
        "     \tTAB        \tnew idea containing",
        "     \tG          \trefetch entire subgraph of selection",
        "     \tS          \texport to a outline file",
        "",
        "+COMMAND",
        "     \tARROWS     \textend all the way",
        "     \t/          \trefocus current favorite",
        "     \tD          \tappend onto parent",
        "     \tG          \trefetch entire graph",
        "",
        "+COMMAND + OPTION",
        "     \tDELETE     \tpermanently (not into trash)",
        "     \tHYPHEN     \t-> to[from] titled line, retain children",
        "     \tO          \tshow data files in Finder",
        "",
        "uSHIFT + ARROW KEY (+ COMMAND -> all)",
        "     \tRIGHT      \treveal children",
        "     \tLEFT       \thide children",
        "     \tvertical   \textend selection",
        "",
        "uSHIFT + MOUSE CLICK (with or without drag)",
        "     \t           \t[un]extend selection",
        "",
        "",
        "",
        "bMULTIPLE SELECTED IDEAS:",
        "",
        "uKEY",
        "     \tHYPHEN     \tif first selected idea is titled, -> parent",
        "     \t#          \tmark with ascending numbers",
        "     \tM          \tsort by length (+ OPTION -> backwards)",
        "     \tN          \talphabetize (+ OPTION -> backwards)",
        "     \tR          \treverse order",
        "",
    ]
    
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSTextTabOptionKeyDictionary(_ input: [String: Any]) -> [NSTextTab.OptionKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSTextTab.OptionKey(rawValue: key), value)})
}
