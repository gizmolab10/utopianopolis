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
	case plain     = " "
}


var gShortcuts: ZShortcutsController? { return gControllers.controllerForID(.shortcuts) as? ZShortcutsController }


class ZShortcutsController: ZGenericTableController {


    @IBOutlet var gridView: ZView?
    @IBOutlet var clipView: ZView?
    var tabStops = [NSTextTab]()
    override var controllerID: ZControllerID { return .shortcuts }
    let bold = ZFont.boldSystemFont(ofSize: ZFont.systemFontSize)
	let columnWidth = 290


    override func viewDidLoad() {
        super.viewDidLoad()
        
        var values: [Int] = []
        var offset = 0
        
        for _ in 0...3 {
            values.append(offset)
            values.append(offset + 20)
            values.append(offset + 85)
            
            offset += columnWidth
        }

        for value in values {
            if value != 0 {
                tabStops.append(NSTextTab(textAlignment: .left, location: CGFloat(value), options: convertToNSTextTabOptionKeyDictionary([:])))
            }
        }
        
        view.zlayer.backgroundColor = gBackgroundColor.cgColor
        
        if  let g = gridView,
            let c = clipView {
            g.removeFromSuperview()
            c.addSubview(g)

            g.zlayer.backgroundColor = kClearColor.cgColor

            g.snp.makeConstraints { make in
                make.top.bottom.left.right.equalTo(c)
            }
        }
    }
    
    
    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {} // this controller can IGNORE ALL SIGNALS

    
    func handleEvent(_ iEvent: ZEvent) -> ZEvent? {
        if  let    key = iEvent.key {
            let COMMAND = iEvent.modifierFlags.isCommand
            let OPTION  = iEvent.modifierFlags.isOption
            let SPECIAL = COMMAND && OPTION
            switch key {
            case "?", "/":         gGraphEditor.showHideKeyboardShortcuts()
            case "a": if SPECIAL { gApplication.showHideAbout() }
            case "p":              view.printView()
            case "r": if COMMAND { sendEmailBugReport() }
            case "w": if COMMAND { gGraphEditor.showHideKeyboardShortcuts(hide: true) }

            default: break
            }
        }
        
        return nil
    }


    // MARK:- shortcuts table
    // MARK:-
	
	
	var clickCoordinates: (Int, Int)? {
		if  let table = genericTableView,
			let row = table.selectedRowIndexes.first {
			let screenLocation = NSEvent.mouseLocation
			if  let windowLocation = table.window?.convertPoint(fromScreen: screenLocation) {
				let l = table.convert(windowLocation, from: nil)
				let column = Int(floor(l.x / CGFloat(columnWidth)))
				table.deselectRow(row)
				
				return (row, min(3, column))
			}
		}
		
		return nil
	}


    override func numberOfRows(in tableView: ZTableView) -> Int {
        return max(columnOne.count, max(columnTwo.count, max(columnThree.count, columnFour.count)))
    }
    
    
    func tableView(_ tableView: ZTableView, objectValueFor tableColumn: ZTableColumn?, row: Int) -> Any? {
		let     cellString = NSMutableAttributedString()
        let      paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = tabStops

        for column in 0...3 {
            cellString.append(attributedString(for: row, column: column))
        }

        cellString.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraph as Any, range: NSMakeRange(0, cellString.length))

        return cellString
	}
	
	
	func tableViewSelectionIsChanging(_ notification: Notification) {
		if  let (row, column) = clickCoordinates,
			let hyperlink = url(for: row, column: column) {
			hyperlink.openAsURL()
		}
	}
	
	
	func strings(for row: Int, column: Int) -> (String, String) {
		let columnStrings = [columnOne, columnTwo, columnThree, columnFour]
		let       strings = columnStrings[column]
		let 		index = row * 2
		
		return index >= strings.count ? ("", "") : (strings[index], strings[index + 1])
	}
	
	
	func url(for row: Int, column: Int) -> String? {
		let m = "https://medium.com/@sand_74696/"
		let (_, url) = strings(for: row, column: column)

		return url.isEmpty ? nil : m + url
	}
	
	
	func attributedString(for row: Int, column: Int) -> NSMutableAttributedString {
		let (raw, url) = strings(for: row, column: column)
        let       type = ZShortcutType(rawValue: raw.substring(with: NSMakeRange(0, 1))) // grab first character
        var       text = raw.substring(with: NSMakeRange(1, raw.length - 1))             // grab remaining characters
        var attributes = [String : Any] ()
		let     hasURL = !url.isEmpty
        var     prefix = "   "

        switch type {
        case .bold?:
            attributes = [NSAttributedString.Key.font.rawValue : bold as Any]
        case .append?, .underline?:
            attributes = [NSAttributedString.Key.underlineStyle.rawValue : 1 as Any]
            
            if type == .append {
                prefix += "+ "
            }
            
		case .plain?:
			if  hasURL {
				attributes = [NSAttributedString.Key.foregroundColor.rawValue : NSColor.blue.darker(by: 5.0) as Any]
				text.append(" ...")
			}

			fallthrough

		default:
			prefix = kTab		// for empty lines, including after last row
        }

		var parts   = text.components(separatedBy: kTab)
		let result  = NSMutableAttributedString(string: prefix)
		let main    = parts[0].stripped

		if  type == .plain {
			result.append(NSAttributedString(string: main))
		} else {
			result.append(NSAttributedString(string: main, attributes: convertToOptionalNSAttributedStringKeyDictionary(attributes)))
		}

		if  parts.count > 1 {
			let explain = parts[1]

			result.append(NSAttributedString(string: kTab))
			result.append(NSAttributedString(string: explain, attributes: convertToOptionalNSAttributedStringKeyDictionary(attributes)))
		}

        if  text.length < 13 && row != 1 {
            result.append(NSAttributedString(string: kTab)) 	// KLUDGE to fix bug in first column where underlined "KEY" doesn't have enough subsequent tabs
        }

		result.append(NSAttributedString(string: kTab))

        return result
    }


    let columnOne: [String] = [
        "", "",
        "bALWAYS:\t", "",
        "", "",
        "uKEY", "",
		" RETURN     \tbegin or end editing text", "",
		" SPACE      \tcreate subordinate idea", "",
		" TAB        \tcreate next idea", "",
        "", "",
        "+CONTROL", "",
		" COMMA      \ttoggle browsing: un/confined", "",
		" DELETE     \tshow trash", "",
		" PERIOD     \ttoggle next ideas precede/follow", "",
		" SPACE      \tcreate an idea", "",
		" /          \tremove from focus ring, -> prior", 				"focusing-your-thinking-a53adb16bba",
        "", "",
        "+COMMAND", "",
		" COMMA      \tshow or hide preferences", 						"help-inspector-view-c360241147f2",
		" HYPHEN     \tconvert text to or from 'titled line'", 			"lines-37426469b7c6",
		" P          \tprint the graph (or this window)", "",
        "", "",
        "+COMMAND + OPTION", "",
		" A          \tshow About Thoughtful", "",
		" R          \treport a problem", "",
		" /          \tshow or hide this window", "",
        "", "",
        "uCONTROL + COMMAND + OPTION", "",
		"            \tshow or hide indicators", "",
        "", "",
        "", "",
        "", "",
        "bSEARCH BAR:", "",
        "", "",
        "uKEY", "",
		" RETURN     \tperform search", "",
		" ESCAPE     \tdismisss search bar", "",
        "", "",
        "+COMMAND", "",
		" A          \tselect all search text", "",
		" F          \tdismisss search bar", "",
        "", "",
    ]

    
    let columnTwo: [String] = [
        "", "",
        "bEDITING TEXT:", "",
        "", "",
        "uKEY", "",
		" ESCAPE     \tcancel edit, discarding changes", "",
        "", "",
        "+COMMAND", "",
		" PERIOD     \tcancel edit, discarding changes", "",
		" A          \tselect all text", "",
        "", "",
        "+COMMAND + OPTION", "",
		" PERIOD     \ttoggle: next ideas precede/follow,", "",
		" \t(and) move idea up/down", "",
		"", "",
		"", "",
		"", "",
		"bEDITING (TEXT IS SELECTED):", "",
		"", "",
		" surround:  \t| [ { ( < \" SPACE", "",
		"", "",
		"+COMMAND", "",
		" D          \tif all selected, append onto parent", 			"parent-child-tweaks-bf067abdf461",
		"            \tif not all selected, create as a child", 		"parent-child-tweaks-bf067abdf461",
		" L          \t-> lowercase", "",
		" U          \t-> uppercase", "",
		"", "",
		"", "",
		"", "",
		"", "",
		"", "",
		"bSEARCH RESULTS:", "",
		"", "",
		"uKEY", "",
		" RETURN    \tfocus on selected result", "",
		"", "",
		"uARROW KEY", "",
		" LEFT      \texit search", "",
		" RIGHT     \tfocus on selected result", "",
		" vertical  \tbrowse results (wraps around)", "",
		"", "",
    ]
    

    let columnThree: [String] = [
		"", "",
		"bBROWSING (NOT EDITING TEXT):", "",
		"", "",
		" mark:      \t" + kMarkingCharacters, 							"extras-2a9b1a7db21f",
		"", "",
		"uKEY", "",
		" ARROWS     \tnavigate graph", "",
		" COMMA      \ttoggle browsing: un/confined", "",
		" DELETE     \tselected ideas and their progeny", "",
		" HYPHEN     \tadd 'line', or un/title it", 					"lines-37426469b7c6",
		" PERIOD     \ttoggle next ideas precede/follow", "",
		" SPACE      \tcreate an idea", "",
		" /          \tfocus (also, manage favorite)", 					"focusing-your-thinking-a53adb16bba",
		" \\         \tswitch to other graph", "",
		" ;          \t-> prior favorite", 								"focusing-your-thinking-a53adb16bba",
		" '          \t-> next favorite", 								"focusing-your-thinking-a53adb16bba",
		" [          \t-> prior in focus ring", 						"focusing-your-thinking-a53adb16bba",
		" ]          \t-> next in focus ring", 							"focusing-your-thinking-a53adb16bba",
		" =          \tinvoke hyperlink or email", "",
		" A          \tselect all ideas", "",
		" B          \tcreate a bookmark", 								"focusing-your-thinking-a53adb16bba",
		" C          \trecenter the graph", "",
		" D          \tduplicate", "",
		" E          \tcreate or edit email", 							"extras-2a9b1a7db21f",
		" F          \tsearch", "",
		" G          \trefetch children of selection", 					"cloud-vs-file-f3543f7281ac",
		" H          \tcreate or edit hyperlink", 						"extras-2a9b1a7db21f",
		" I          \tun/color the text", 								"extras-2a9b1a7db21f",
		" L          \t-> lowercase", "",
		" O          \timport from a Thoughtful file", 					"cloud-vs-file-f3543f7281ac",
		" R          \treverse order of children", "",
		" S          \tsave to a Thoughtful file", 						"cloud-vs-file-f3543f7281ac",
		" T          \tswap selected idea with parent", 				"parent-child-tweaks-bf067abdf461",
		" U          \t-> uppercase", "",
		"", "",
    ]
    
    
    let columnFour: [String] = [
		"", "",
		"+OPTION", "",
		" ARROWS     \tmove selected idea", "",
		" DELETE     \tretaining children", "",
		" RETURN     \tedit with cursor at end", "",
		" TAB        \tnew idea containing", "",
		" G          \trefetch entire subgraph of selection", 			"cloud-vs-file-f3543f7281ac",
		" S          \texport to a outline file", 						"cloud-vs-file-f3543f7281ac",
		"", "",
		"+COMMAND", "",
		" ARROWS     \textend all the way", 							"selecting-ideas-cc2939720e53",
		" /          \trefocus current favorite", 						"focusing-your-thinking-a53adb16bba",
		" D          \tappend onto parent", 							"parent-child-tweaks-bf067abdf461",
		" G          \trefetch entire graph", 							"cloud-vs-file-f3543f7281ac",
		"", "",
		"+COMMAND + OPTION", "",
		" DELETE     \tpermanently (not into trash)", "",
		" HYPHEN     \t-> to/from titled line, retain children", 		"lines-37426469b7c6",
		" O          \tshow data files in Finder", 						"cloud-vs-file-f3543f7281ac",
		"", "",
		"+MOUSE CLICK", "",
		" COMMAND    \tmove entire graph", "",
		" SHIFT      \tun/extend selection", 							"selecting-ideas-cc2939720e53",
		"", "",
		"uARROW KEY + SHIFT (+ COMMAND -> all)", "",
		" LEFT       \thide children", 									"focusing-your-thinking-a53adb16bba",
		" RIGHT      \treveal children", 								"focusing-your-thinking-a53adb16bba",
		" vertical   \textend selection", 								"selecting-ideas-cc2939720e53",
		"", "",
		"", "",
		"", "",
		"bBROWSING (MULTIPLE IDEAS SELECTED):", "",
		"", "",
		"uKEY", "",
		" HYPHEN     \tif first selected idea is titled, -> parent", 	"lines-37426469b7c6",
		" #          \tmark with ascending numbers", 					"extras-2a9b1a7db21f",
		" M          \tsort by length (+ OPTION -> backwards)", 		"organize-fcdc44ac04e4",
		" N          \talphabetize (+ OPTION -> backwards)", 			"organize-fcdc44ac04e4",
		" R          \treverse order", "",
		"", "",
    ]
    
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSTextTabOptionKeyDictionary(_ input: [String: Any]) -> [NSTextTab.OptionKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSTextTab.OptionKey(rawValue: key), value)})
}
