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

var gShortcutsWindowController: NSWindowController?
var gShortcutsController: ZShortcutsController? { return gControllers.controllerForID(.idShortcuts) as? ZShortcutsController }

class ZShortcutsController: ZGenericTableController {

	@IBOutlet var      clipView : ZView?
	@IBOutlet var  dotsGridView : ZView?
	@IBOutlet var notesGridView : ZView?
	@IBOutlet var graphGridView : ZView?
	override  var  controllerID : ZControllerID { return .idShortcuts }
	var                    mode : ZWorkMode? // dot, note, graph
	let           noteShortcuts = ZNoteShortcuts()
	let          graphShortcuts = ZGraphShortcuts()
	let          dotDecorations = ZDotDecorations()
	override func numberOfRows(in tableView: ZTableView) -> Int { return shortcuts.numberOfRows }
	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? { return shortcuts.objectValueFor(row) }

	var shortcuts: ZDocumentation {
		switch mode {
			case   .dotMode: return dotDecorations
			case  .noteMode: return noteShortcuts
			default:         return graphShortcuts
		}
	}

	var gridView: ZView? {
		switch mode {
			case   .dotMode: return  dotsGridView
			case  .noteMode: return notesGridView
			case .graphMode: return graphGridView
			default:         return nil
		}
	}

    override func viewDidLoad() {
        super.viewDidLoad()
		graphShortcuts.setup()
		dotDecorations.setup() // empty
		noteShortcuts .setup() // empty

		view.zlayer.backgroundColor = .clear
		mode                        = .graphMode
	}

	override func viewWillAppear() {
		super.viewWillAppear()
		update()
    }

	func update() {
		if  let c = clipView {
			for s in c.subviews {
				s.removeFromSuperview()
			}

			if  let g = gridView {
				c.addSubview(g)

				g.snp.makeConstraints { make in
					make.top.bottom.left.right.equalTo(c) // text and grid scroll together
				}
			}

			c.applyToAllSubviews { subview in
				subview.zlayer.backgroundColor = .clear
			}
		}

		genericTableUpdate()
		view.setAllSubviewsNeedDisplay()
	}

	func show(_ show: Bool? = nil, flags: ZEventFlags) {
		let  COMMAND = flags.isCommand
		let  CONTROL = flags.isControl
		let   OPTION = flags.isOption
		var nextMode : ZWorkMode?

		if            COMMAND {
			if       !OPTION && CONTROL {
				nextMode =  .noteMode
			} else if OPTION && CONTROL {
				nextMode =   .dotMode
			} else if OPTION {
				nextMode = .graphMode
			}
		}

		let controller = gShortcutsWindowController
		let     isOpen = controller?.window?.isKeyWindow ?? false
		let       same = mode == nextMode
		let      close = !(show ?? !(isOpen && same))

		if  close  {
			controller?.window?.close()
		} else {
			mode           = nextMode

			update()
			controller?.showWindow(nil)
		}
	}

    func handleEvent(_ iEvent: ZEvent) -> ZEvent? {
        if  let     key = iEvent.key {
			let   flags = iEvent.modifierFlags
            let COMMAND = flags.isCommand
            let OPTION  = flags.isOption
            let SPECIAL = COMMAND && OPTION
			switch key {
				case "?",
					 "/": if COMMAND { show(flags: flags) }
				case "a": if SPECIAL { gApplication.showHideAbout() }
				case "p": if SPECIAL { cycleSkillLevel() } else { view.printView() }
				case "q":              gApplication.terminate(self)
				case "r": if COMMAND { sendEmailBugReport() }
				case "w": if COMMAND { show(false, flags: flags) } // close the window
				
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

	func tableViewSelectionIsChanging(_ notification: Notification) {
		if  let (row, column) = clickCoordinates,
			let hyperlink = shortcuts.url(for: row, column: column) {
			hyperlink.openAsURL()
		}
	}

}
