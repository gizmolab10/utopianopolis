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
let gAllHelpModes : [ZHelpMode] = [.basicMode, .allMode, .dotMode]

class ZHelpController: ZGenericTableController {

	@IBOutlet var      clipView : ZView?
	@IBOutlet var  dotsHelpGrid : ZHelpGridView?
	@IBOutlet var notesHelpGrid : ZHelpGridView?
	@IBOutlet var graphHelpGrid : ZHelpGridView?
	override  var  controllerID : ZControllerID  { return .idHelp }
	var                helpData : ZHelpData      { return helpData(for: gCurrentHelpMode) }
	var                gridView : ZHelpGridView? { return gridView(for: gCurrentHelpMode) }
	var         titleBarButtons : ZHelpButtonsView?
	let            dotsHelpData =  ZHelpDotsData()
	let           graphHelpData = ZHelpGraphData()

	func helpData(for iMode: ZHelpMode) -> ZHelpData {
		switch iMode {
			case   .dotMode: return  dotsHelpData
			default:         return graphHelpData
		}
	}

	func gridView(for iMode: ZHelpMode) -> ZHelpGridView? {
		switch iMode {
			case   .dotMode: return  dotsHelpGrid
			default:         return graphHelpGrid
		}
	}

	// MARK:- events
	// MARK:-

	override func viewWillAppear() {
		super.viewWillAppear()
		update()
	}

	func update() {
		view.zlayer.backgroundColor = gBackgroundColor.cgColor

		updateTitleBar()
		genericTableUpdate()
		updateGridVisibility()
	}

	override func setup() {
		view.zlayer.backgroundColor = .white
		let                       m = gCurrentHelpMode

		super        .setup()
		dotsHelpData .setup(for: m)
		graphHelpData.setup(for: m)
		setupGridViews()
		setupTitleBar()

		gCurrentHelpMode = .noMode // set temporarily so show does not dismiss window

		show(nextMode: m)
	}

	func show(_ iShow: Bool? = nil, flags: ZEventFlags) {
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

			show(iShow, nextMode: nextMode)
		}
	}

	func show(_ iShow: Bool? = nil, nextMode: ZHelpMode?) {
		if  let         next = nextMode {
			let   controller = gHelpWindowController
			let        isKey = gHelpWindow?.isKeyWindow ?? false
			let         same = gCurrentHelpMode == next
			let         show = iShow ?? !(isKey && same)

			if !show  {
				gHelpWindow?.close()
			} else {
				gCurrentHelpMode = next

				controller?.showWindow(nil)
				update()
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

			for m in gAllHelpModes {
				if  let         g = gridView(for: m) {
					let      data = helpData(for: m)
					g.helpData    = data

					g.removeFromSuperview()
					c.addSubview(g)

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
		let graphModes: [ZHelpMode] = [.basicMode, .allMode]

		func shouldHide(_ mode: ZHelpMode) -> Bool {
			return mode != gCurrentHelpMode && (!graphModes.contains(mode) || !graphModes.contains(gCurrentHelpMode))
		}

		for mode in gAllHelpModes {
			gridView(for: mode)?.isHidden = shouldHide(mode)
		}

		gridView?.setNeedsDisplay()
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
				let         column = Int(floor(l.x / CGFloat(helpData.columnWidth)))

				table.deselectRow(row)
				
				return (row, min(3, column))
			}
		}

		#endif
		
		return nil
	}

	override func numberOfRows(in tableView: ZTableView) -> Int {
		return helpData.countOfRows
    }

	func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
		return helpData.rowHeight
	}

	func tableView(_ tableView: ZTableView, objectValueFor tableColumn: ZTableColumn?, row: Int) -> Any? {
		return helpData.objectValueFor(row)
	}

	func tableViewSelectionIsChanging(_ notification: Notification) {
		if  let (row, column) = clickCoordinates,
			let hyperlink = helpData.url(for: row, column: column) {
			hyperlink.openAsURL()
		}
	}

}