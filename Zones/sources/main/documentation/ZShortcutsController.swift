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

var gShortcutsController: ZShortcutsController? { return gControllers.controllerForID(.idShortcuts) as? ZShortcutsController }
var gShortcutsWindowController: NSWindowController? // instantiated once

class ZShortcutsController: ZGenericTableController {

	@IBOutlet var      clipView : ZView?
	@IBOutlet var  dotsGridView : ZView?
	@IBOutlet var notesGridView : ZView?
	@IBOutlet var graphGridView : ZView?
	override  var  controllerID : ZControllerID { return .idShortcuts }
	var                gridView : ZView?        { return gridView(for: mode) }
	var                    mode : ZWorkMode = .graphMode // dot, note, graph
	let          dotDecorations = ZDotDecorations()
	let          graphShortcuts = ZGraphShortcuts()
	let           noteShortcuts =  ZNoteShortcuts()
	let  allModes : [ZWorkMode] = [.graphMode, .noteMode, .dotMode]

	var shortcuts: ZDocumentation {
		switch mode {
			case  .noteMode: return noteShortcuts
			case   .dotMode: return dotDecorations
			default:         return graphShortcuts
		}
	}

	override func viewWillAppear() {
		super.viewWillAppear()
		update()
	}

	override func setup() {
		super         .setup()
		graphShortcuts.setup()
		dotDecorations.setup() // empty
		noteShortcuts .setup() // empty

		view.zlayer.backgroundColor = .white

		if  let c = clipView {
			c.zlayer.backgroundColor = .clear

			for m in allModes {
				if  let g = gridView(for: m) {
					if  g.superview == nil {
						c.addSubview(g)

						g.zlayer.backgroundColor = .clear

						g.snp.makeConstraints { make in
							make.top.bottom.left.right.equalTo(c) // text and grid scroll together
						}
					}

					g.isHidden = m != mode
				}
			}
		}
	}

	func update() {
		for m in allModes {
			gridView(for: m)?.isHidden = m != mode
		}

		genericTableUpdate()
		view.setAllSubviewsNeedDisplay()
	}

	func gridView(for iMode: ZWorkMode) -> ZView? {
		switch iMode {
			case   .dotMode: return  dotsGridView
			case  .noteMode: return notesGridView
			case .graphMode: return graphGridView
			default:         return nil
		}
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

		if  let       next = nextMode {
			let controller = gShortcutsWindowController
			let     isOpen = controller?.window?.isKeyWindow ?? false
			let       same = mode == next
			let      close = !(show ?? !(isOpen && same))

			if  close  {
				controller?.window?.close()
			} else {
				mode       = next

				update()
				controller?.showWindow(nil)
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
					 "/": if COMMAND { gShortcutsController?.show(flags: flags) }
				case "a": if SPECIAL { gApplication.showHideAbout() }
				case "p": if SPECIAL { cycleSkillLevel() } else { view.printView() }
				case "q":              gApplication.terminate(self)
				case "r": if COMMAND { sendEmailBugReport() }
				case "w": if COMMAND { gShortcutsController?.show(false, flags: flags) }
				
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
