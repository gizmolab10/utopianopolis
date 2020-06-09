//
//  ZShortcutsController.swift
//  Seriously
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

var gShortcuts: ZShortcutsController? { return gControllers.controllerForID(.idShortcuts) as? ZShortcutsController }
let gShortcutsController = NSStoryboard(name: "Shortcuts", bundle: nil).instantiateInitialController() as? NSWindowController // instantiated once

class ZShortcutsController: ZGenericTableController {

	@IBOutlet var      clipView : ZView?
	@IBOutlet var graphGridView : ZView?
	override  var  controllerID : ZControllerID { return .idShortcuts }
	var                    mode : ZWorkMode? // dot, note, graph
	let           noteShortcuts = ZNoteShortcuts()
	let          graphShortcuts = ZGraphShortcuts()
	let          dotDecorations = ZDotDecorations()

    override func viewDidLoad() {
        super.viewDidLoad()
		graphShortcuts.setup()
		dotDecorations.setup() // empty
		noteShortcuts .setup() // empty

		view.zlayer.backgroundColor = gBackgroundColor.cgColor
        
		if  let c = clipView,
			let g = graphGridView {
            g.removeFromSuperview()
            c.addSubview(g)

            g.zlayer.backgroundColor = kClearColor.cgColor

            g.snp.makeConstraints { make in
                make.top.bottom.left.right.equalTo(c) // text and grid scroll together
            }
        }
    }

    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		genericTableView?.reloadData()
	}
    
    func handleEvent(_ iEvent: ZEvent) -> ZEvent? {
        if  let     key = iEvent.key {
			let   flags = iEvent.modifierFlags
            let COMMAND = flags.isCommand
            let OPTION  = flags.isOption
            let SPECIAL = COMMAND && OPTION
			switch key {
				case "?",
					 "/": if COMMAND { gControllers.showShortcuts(flags: flags) }
				case "a": if SPECIAL { gApplication.showHideAbout() }
				case "p": if SPECIAL { cycleSkillLevel() } else { view.printView() }
				case "q":              gApplication.terminate(self)
				case "r": if COMMAND { sendEmailBugReport() }
				case "w": if COMMAND { gControllers.showShortcuts(false, flags: flags) }
				
				default: break
			}
        }
        
        return nil
    }

	// MARK:- shortcuts table
    // MARK:-

	var clickCoordinates: (Int, Int)? {
		#if os(OSX)
		if  let table = genericTableView,
			let row = table.selectedRowIndexes.first {
			let screenLocation = NSEvent.mouseLocation
			if  let windowLocation = table.window?.convertPoint(fromScreen: screenLocation) {
				let l = table.convert(windowLocation, from: nil)
				let column = Int(floor(l.x / CGFloat(graphShortcuts.columnWidth)))
				table.deselectRow(row)
				
				return (row, min(3, column))
			}
		}
		#endif
		
		return nil
	}

	override func numberOfRows(in tableView: ZTableView) -> Int {
		return graphShortcuts.numberOfRows
    }

	func tableView(_ tableView: ZTableView, objectValueFor tableColumn: ZTableColumn?, row: Int) -> Any? {
		let     cellString = NSMutableAttributedString()
        let      paragraph = NSMutableParagraphStyle()
		paragraph.tabStops = graphShortcuts.tabStops

        for column in 0...3 {
            cellString.append(graphShortcuts.attributedString(for: row, column: column))
        }

        cellString.addAttribute(.paragraphStyle, value: paragraph as Any, range: NSMakeRange(0, cellString.length))

        return cellString
	}

	func tableViewSelectionIsChanging(_ notification: Notification) {
		if  let (row, column) = clickCoordinates,
			let hyperlink = graphShortcuts.url(for: row, column: column) {
			hyperlink.openAsURL()
		}
	}

}
