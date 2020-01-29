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

var gShortcuts: ZShortcutsController? { return gControllers.controllerForID(.idShortcuts) as? ZShortcutsController }
let gShortcutsController = NSStoryboard(name: "Shortcuts", bundle: nil).instantiateInitialController() as? NSWindowController // instantiated once

class ZShortcutsController: ZGenericTableController {

	@IBOutlet var gridView        : ZView?
    @IBOutlet var clipView        : ZView?
    override  var controllerID    : ZControllerID { return .idShortcuts }
	let shortcuts = ZShortcuts()

    override func viewDidLoad() {
        super.viewDidLoad()
		shortcuts.setup()

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

    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		// look for changes in work mode
	}
    
    func handleEvent(_ iEvent: ZEvent) -> ZEvent? {
        if  let     key = iEvent.key {
			let   flags = iEvent.modifierFlags
            let COMMAND = flags.isCommand
            let OPTION  = flags.isOption
            let SPECIAL = COMMAND && OPTION
			switch key {
				case "?", "/":         gControllers.showShortcuts()
				case "a": if SPECIAL { gApplication.showHideAbout() }
				case "p":              view.printView()
				case "r": if COMMAND { sendEmailBugReport() }
				case "w": if COMMAND { gControllers.showShortcuts(false) }
				
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
				let column = Int(floor(l.x / CGFloat(shortcuts.columnWidth)))
				table.deselectRow(row)
				
				return (row, min(3, column))
			}
		}
		#endif
		
		return nil
	}

	override func numberOfRows(in tableView: ZTableView) -> Int {
		return shortcuts.numberOfRows
    }

	func tableView(_ tableView: ZTableView, objectValueFor tableColumn: ZTableColumn?, row: Int) -> Any? {
		let     cellString = NSMutableAttributedString()
        let      paragraph = NSMutableParagraphStyle()
		paragraph.tabStops = shortcuts.tabStops

        for column in 0...3 {
            cellString.append(shortcuts.attributedString(for: row, column: column))
        }

        cellString.addAttribute(.paragraphStyle, value: paragraph as Any, range: NSMakeRange(0, cellString.length))

        return cellString
	}

	func tableViewSelectionIsChanging(_ notification: Notification) {
		if  let (row, column) = clickCoordinates,
			let hyperlink = shortcuts.url(for: row, column: column) {
			hyperlink.openAsURL()
		}
	}

}
