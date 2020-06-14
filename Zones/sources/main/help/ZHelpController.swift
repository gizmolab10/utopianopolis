//
//  ZHelpController.swift
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

var gHelpController: ZHelpController? { return gControllers.controllerForID(.idHelp) as? ZHelpController }
var gHelpWindowController: NSWindowController? // instantiated once

class ZHelpController: ZGenericTableController {

	@IBOutlet var      clipView : ZView?
	@IBOutlet var  dotsHelpGrid : ZHelpGridView?
	@IBOutlet var notesHelpGrid : ZHelpGridView?
	@IBOutlet var graphHelpGrid : ZHelpGridView?
	override  var  controllerID : ZControllerID  { return .idHelp }
	var                    help : ZHelp          { return help(for: mode) }
	var                gridView : ZHelpGridView? { return gridView(for: mode) }
	var                    mode : ZWorkMode = .graphMode
	let  allModes : [ZWorkMode] = [.graphMode, .noteMode, .dotMode]
	let                dotsHelp =  ZDotsHelp()
	let               graphHelp = ZGraphHelp()
	let               notesHelp = ZNotesHelp()

	override func viewWillAppear() {
		super.viewWillAppear()
		update()
	}

	override func setup() {
		super         .setup()
		graphHelp.setup()
		dotsHelp .setup() // empty
		notesHelp.setup() // empty

		if  let m = gLastChosenCheatSheet {
			mode  = m
		}

		view.zlayer.backgroundColor = .white

		if  let c = clipView {
			c.zlayer.backgroundColor = .clear

			for m in allModes {
				if  let g = gridView(for: m) {
					g.removeFromSuperview()
					c.addSubview(g)
					g.help = help(for: m)

					if  let t = genericTableView {
						g.snp.makeConstraints { make in
							make.top.bottom.left.right.equalTo(t) // text and grid scroll together
						}
					}

					g.zlayer.backgroundColor = .clear
					g.isHidden               = true
				}
			}
		}

		if  let m = gLastChosenCheatSheet {
			mode  = .startupMode

			show(nextMode: m)
		}
	}

	func update() {
		updateGridVisibility()
		genericTableUpdate()
		view.setAllSubviewsNeedDisplay()
	}

	func updateGridVisibility() {
		for m in allModes {
			let                   show = m == mode
			gridView(for: m)?.isHidden = !show
		}
	}

	func help(for iMode: ZWorkMode) -> ZHelp {
		switch iMode {
			case   .dotMode: return dotsHelp
			case  .noteMode: return notesHelp
			default:         return graphHelp
		}
	}

	func gridView(for iMode: ZWorkMode) -> ZHelpGridView? {
		switch iMode {
			case   .dotMode: return  dotsHelpGrid
			case  .noteMode: return notesHelpGrid
			case .graphMode: return graphHelpGrid
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

			self.show(show, nextMode: nextMode)
		}
	}

	func show(_ show: Bool? = nil, nextMode: ZWorkMode?) {
		if  let       next = nextMode {
			let controller = gHelpWindowController
			let     isOpen = gHelpWindow?.isKeyWindow ?? false
			let       same = mode == next
			let      close = !(show ?? !(isOpen && same))

			if  close  {
				gHelpWindow?.close()
			} else {
				mode                  = next
				gLastChosenCheatSheet = next

				update()
				controller?.showWindow(nil)
			}
		}
	}

	override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		genericTableView?.reloadData()
	}
    
    func handleEvent(_ iEvent: ZEvent) -> ZEvent? {
        if  let      key = iEvent.key {
			let    flags = iEvent.modifierFlags
			let   OPTION = flags.isOption
            let  COMMAND = flags.isCommand
            let  SPECIAL = COMMAND && OPTION
			switch   key {
				case "?", "/":         show(       flags: flags)
				case "w":              show(false, flags: flags)
				case "q":              gApplication.terminate(self)
				case "a": if SPECIAL { gApplication.showHideAbout() }
				case "p": if SPECIAL { cycleSkillLevel() } else { view.printView() }
				case "r": if COMMAND { sendEmailBugReport() }
				
				default: break
			}
        }
        
        return nil
    }

	// MARK:- help table
    // MARK:-

	var clickCoordinates: (Int, Int)? {

		#if os(OSX)

		if  let              table = genericTableView,
			let                row = table.selectedRowIndexes.first {
			let     screenLocation = NSEvent.mouseLocation
			if  let windowLocation = table.window?.convertPoint(fromScreen: screenLocation) {
				let              l = table.convert(windowLocation, from: nil)
				let         column = Int(floor(l.x / CGFloat(help.columnWidth)))

				table.deselectRow(row)
				
				return (row, min(3, column))
			}
		}

		#endif
		
		return nil
	}

	override func numberOfRows(in tableView: ZTableView) -> Int {
		return help.countOfRows
    }

	func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
		return help.rowHeight
	}

	func tableView(_ tableView: ZTableView, objectValueFor tableColumn: ZTableColumn?, row: Int) -> Any? {
		return help.objectValueFor(row)
	}

	func tableViewSelectionIsChanging(_ notification: Notification) {
		if  let (row, column) = clickCoordinates,
			let hyperlink = help.url(for: row, column: column) {
			hyperlink.openAsURL()
		}
	}

}
