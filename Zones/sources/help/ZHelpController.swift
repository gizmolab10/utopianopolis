//
//  ZHelpController.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/13/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//

import Foundation
import SnapKit

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
	var         titleBarButtons : ZHelpButtonsView?
	var                    mode : ZHelpMode  = .noMode
	let  allModes : [ZHelpMode] = [.basicMode, .dotMode]
	let                dotsHelp =  ZDotsHelp()
	let               graphHelp = ZGraphHelp()

	// MARK:- events
	// MARK:-

	override func viewWillAppear() {
		super.viewWillAppear()
		update()
	}

	func update() {
		updateTitleBar()
		updateGridVisibility()
		genericTableUpdate()
		view.setAllSubviewsNeedDisplay()
	}

	override func setup() {
		super    .setup()
		graphHelp.setup()
		dotsHelp .setup()

		if  let m = gLastChosenCheatSheet {
			mode  = m
		}

		view.zlayer.backgroundColor = .white

		setupGridViews()
		setupTitleBar()

		if  let m = gLastChosenCheatSheet {
			mode  = .noMode

			show(nextMode: m)
		}
	}

	func show(_ show: Bool? = nil, flags: ZEventFlags) {
		let  COMMAND = flags.isCommand
		let  CONTROL = flags.isControl
		let   OPTION = flags.isOption
		var nextMode : ZHelpMode?

		if            COMMAND {
			if       !OPTION && CONTROL {
				nextMode =  .noteMode
			} else if OPTION && CONTROL {
				nextMode =   .dotMode
			} else if OPTION {
				nextMode = .basicMode
			}

			self.show(show, nextMode: nextMode)
		}
	}

	func show(_ show: Bool? = nil, nextMode: ZHelpMode?) {
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

	// MARK:- title bar
	// MARK:-

	func setupTitleBar() {
		if  let           window = view.window {
			let buttons          = ZHelpButtonsView()
			let titleBarView     = window.standardWindowButton(.closeButton)!.superview!
			titleBarButtons      = buttons
			buttons.isInTitleBar = true

			titleBarView.addSubview(titleBarButtons!)
			buttons.snp.removeConstraints()
			buttons.snp.makeConstraints { make in
				make.centerX.top.bottom.equalToSuperview()
			}
			buttons.updateAndRedraw()
		}
	}

	func updateTitleBar() {
		titleBarButtons?.updateAndRedraw()
	}

	// MARK:- grid
	// MARK:-

	func setupGridViews() {
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
	}

	func updateGridVisibility() {
		for m in allModes {
			let                   show = m == mode
			gridView(for: m)?.isHidden = !show
		}
	}

	func help(for iMode: ZHelpMode) -> ZHelp {
		switch iMode {
			case   .dotMode: return  dotsHelp
			default:         return graphHelp
		}
	}

	func gridView(for iMode: ZHelpMode) -> ZHelpGridView? {
		switch iMode {
			case   .dotMode: return  dotsHelpGrid
			default:         return graphHelpGrid
		}
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
