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

var gHelpWindowController       : NSWindowController?         // instantiated once, in startupCloudAndUI
var gHelpController             : ZHelpController? { return gControllers.controllerForID(.idHelp) as? ZHelpController }
let gAllHelpModes : [ZHelpMode] = [.dotMode, .basicMode, .middleMode, .proMode, .essayMode]

class ZHelpController: ZGenericTableController {

	@IBOutlet var      clipView : ZView?
	@IBOutlet var   mapHelpGrid : ZHelpGridView?
	@IBOutlet var  dotsHelpGrid : ZHelpGridView?
	@IBOutlet var essayHelpGrid : ZHelpGridView?
	override  var  controllerID : ZControllerID  { return .idHelp }
	var                helpData : ZHelpData      { return helpData(for: gCurrentHelpMode) }
	var                gridView : ZHelpGridView? { return gridView(for: gCurrentHelpMode) }
	var         titleBarButtons = ZHelpButtonsView()
	let           essayHelpData = ZHelpEssayData()
	let            dotsHelpData = ZHelpDotsData()
	let             mapHelpData = ZHelpMapData()
	var               isShowing = false

	func helpData(for iMode: ZHelpMode) -> ZHelpData {
		switch iMode {
			case .essayMode: return essayHelpData
			case   .dotMode: return  dotsHelpData
			default:         return   mapHelpData
		}
	}

	func gridView(for iMode: ZHelpMode) -> ZHelpGridView? {
		switch iMode {
			case .essayMode: return essayHelpGrid
			case .dotMode:   return dotsHelpGrid
			default:         return mapHelpGrid
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

		titleBarButtons.updateAndRedraw()
		genericTableUpdate()
		updateGridVisibility()
	}

	override func setup() {
		view.zlayer.backgroundColor = .white
		let                       m = gCurrentHelpMode

		super         .setup()
		essayHelpData .setup(for: m)
		dotsHelpData  .setup(for: m)
		mapHelpData   .setup(for: m)
		setupGridViews()
		setupTitleBar()

		if !isShowing {
			gCurrentHelpMode = .noMode // set temporarily so show does not dismiss window

			show(mode: m)
		}
	}

	func show(_ iShow: Bool? = nil, flags: ZEventFlags = ZEventFlags()) {
		var nextMode = gCurrentHelpMode
 		let  COMMAND = flags.isCommand
		let  CONTROL = flags.isControl
		let   OPTION = flags.isOption

		if             COMMAND {
			if         OPTION && !CONTROL {
				nextMode = .basicMode
			} else if  OPTION &&  CONTROL {
				nextMode =   .dotMode
			} else if !OPTION &&  CONTROL {
				nextMode = .essayMode
			}
		}

		show(iShow, mode: nextMode)
	}

	func showHelp(for mode: ZHelpMode) {
		show(true, mode: mode)         // side-effect: sets gCurrentHelpMode
		gSignal([.sStartupButtons])    // change highlight of help buttons in startup view
	}

	func show(_ iShow: Bool? = nil, mode: ZHelpMode?) {
		if  let         next = mode {
			let   controller = gHelpWindowController
			let        isKey = gHelpWindow?.isKeyWindow ?? false
			let         same = gCurrentHelpMode == next
			let         show = iShow ?? !(isKey && same)

			if !show  {
				gHelpWindow?.close()
			} else {
				gCurrentHelpMode = next
				isShowing        = true   // prevent infinite recursion (where show window causes view did appear, which calls update, which calls show)

				gHelpWindow?.close()      // workaround for dots draw method not being called (perhaps an apple bug?)
				controller?.showWindow(nil)
				update()
				isShowing        = false
			}
		}
	}

	override func shouldHandle(_ kind: ZSignalKind) -> Bool {
		return super.shouldHandle(kind) && (gHelpWindow?.isVisible ?? false)
	}

	override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		genericTableView?.reloadData()
	}

	func handleEvent(_ iEvent: ZEvent) -> ZEvent? {
		if  let      key = iEvent.key {
			let    flags = iEvent.modifierFlags
			let  COMMAND = flags.isCommand
			let  SPECIAL = flags.isSpecial
			switch   key {
				case "?", "/":         show(       flags: flags)
				case "w":              show(false, flags: flags)
				case "p":              view.printView()
				case "q":              gApplication.terminate(self)
				case "a": if SPECIAL { gApplication.showHideAbout() }
				case "r": if COMMAND { sendEmailBugReport() }

				default: break
			}

			if  let arrow = key.arrow {
				switch arrow {
					case .left, .right: titleBarButtons.actuateNextButton(forward: arrow == .right)
					default: break
				}
			}
		}

		return nil
	}

	// MARK:- title bar
	// MARK:-

	func setupTitleBar() {
		if  let                   window = view.window {
			let             titleBarView = window.standardWindowButton(.closeButton)!.superview!
			titleBarButtons.isInTitleBar = true

			if !titleBarView.subviews.contains(titleBarButtons) {
				titleBarView.addSubview(titleBarButtons)
				titleBarButtons.snp.removeConstraints()
				titleBarButtons.snp.makeConstraints { make in
					make.centerX.top.bottom.equalToSuperview()
				}
			}

			titleBarButtons.updateAndRedraw()
		}
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
		let graphModes: [ZHelpMode] = [.basicMode, .middleMode, .proMode]

		func shouldShow(_ mode: ZHelpMode) -> Bool {
			let sameMode  = mode == gCurrentHelpMode
			let matchable = sameMode ? [mode] : [mode, gCurrentHelpMode]
			let showGraph = matchable.intersection(graphModes) == matchable

			return sameMode || showGraph
		}

		for mode in gAllHelpModes {
			let hide = !shouldShow(mode)
			gridView(for: mode)?.isHidden = hide
		}

		gridView?.setNeedsDisplay()
	}

	// MARK:- help table
    // MARK:-

	var clickCoordinates: (Int, Int)? {

		#if os(OSX)

		if  let              table = genericTableView,
			let                row = table.selectedRowIndexes.first {
			let     screenLocation = ZEvent.mouseLocation
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
