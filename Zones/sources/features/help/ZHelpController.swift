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

var gHelpWindowController : NSWindowController?         // instantiated once, in startupCloudAndUI
var gHelpController       : ZHelpController? { return gHelpWindowController?.contentViewController as? ZHelpController }
var gHelpWindow           : ZWindow?         { return gHelpWindowController?.window }
let gAllHelpModes         : [ZHelpMode] = [.dotMode, .basicMode, .middleMode, .proMode, .essayMode]

enum ZHelpMode: String {
	case middleMode = "m"
	case basicMode  = "b"
	case essayMode  = "e"
	case proMode    = "a"
	case dotMode    = "d"
	case noMode     = " "

	var title: String {
		switch self {
		case .middleMode: return "intermediate keys"
		case .essayMode:  return "notes & essays"
		case .basicMode:  return "basic keys"
		case .proMode:    return "all keys"
		case .dotMode:    return "dots"
		default:          return kEmpty
		}
	}

	func isEqual(to mode: ZHelpMode) -> Bool {
		return rawValue == mode.rawValue
	}

}

class ZHelpController: ZGenericTableController {

	@IBOutlet var      clipView : ZView?
	@IBOutlet var   mapHelpGrid : ZHelpGridView?
	@IBOutlet var  dotsHelpGrid : ZHelpGridView?
	@IBOutlet var essayHelpGrid : ZHelpGridView?
	var                helpData : ZHelpData      { return helpData(for: gCurrentHelpMode) }
	var                gridView : ZHelpGridView? { return gridView(for: gCurrentHelpMode) }
	var         titleBarButtons = ZHelpButtonsView()
	let           essayHelpData = ZHelpEssayData()
	let            dotsHelpData = ZHelpDotsData()
	let             mapHelpData = ZHelpMapData()
	var               isShowing = false
	override func shouldHandle(_ kind: ZSignalKind) -> Bool                   { return super.shouldHandle(kind) && (gHelpWindow?.isVisible ?? false) }
	override func handleSignal(_ object: Any?, kind: ZSignalKind)             { genericTableUpdate() }
	func           showHelpFor(_ mode: ZHelpMode)                             { show(true, mode: mode) }   // side-effect: sets gCurrentHelpMode
	func tableView(_ tableView: ZTableView, heightOfRow row: Int) -> CGFloat { return helpData.rowHeight }
	func tableView(_ tableView: ZTableView, objectValueFor tableColumn: ZTableColumn?, row: Int) -> Any? { return helpData.objectValueFor(row) }

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

	// MARK: - display
	// MARK: -

	func helpUpdate() {
		view.zlayer.backgroundColor = gBackgroundColor.cgColor

		titleBarButtons.updateAndRedraw()
		genericTableUpdate()
		updateGridVisibility()
	}

	override func controllerSetup(with mapView: ZMapView?) {
		view.zlayer.backgroundColor = .white
		let                       m = gCurrentHelpMode

		super        .controllerSetup(with: mapView)
		essayHelpData.setupForMode(m)
		dotsHelpData .setupForMode(m)
		mapHelpData  .setupForMode(m)
		gSignal([.sAppearance]) // redraw dots map
		setupGridViews()
		setupTitleBar()

		if !isShowing {
			gCurrentHelpMode = .noMode // set temporarily so show (just below) does not dismiss window

			show(mode: m)
		}
	}

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

	func show(_ iShow: Bool? = nil, flags: ZEventFlags = ZEventFlags()) {
		var     nextMode = gCurrentHelpMode

		if            flags.isAnyMultiple {
			if        flags.exactlySpecial {
				nextMode = .basicMode
			} else if flags.exactlySplayed {
				nextMode = .essayMode
			} else if flags.exactlyUnusual {
				nextMode = .dotMode
			} else if flags.exactlyAll {
				nextMode = .proMode
			}
		}

		show(iShow, mode: nextMode)
	}

	func show(_ iShow: Bool? = nil, mode: ZHelpMode?) {
		if  let        next = mode,
			let isKeyWindow = gHelpWindow?.isKeyWindow {
			let        show = iShow ?? !isKeyWindow

			if !show  {
				gHelpWindow?.close()
			} else {
				gCurrentHelpMode = next
				isShowing        = true                   // prevent infinite recursion (where update (below) calls show)

				gHelpWindow?.close()                      // workaround to force a call to the dots draw method (perhaps an apple bug?)
				gHelpController?.helpData.prepareStrings()
				gHelpWindowController?.showWindow(self)   // bring to front
				helpUpdate()

				isShowing        = false
			}
		}
	}

	// MARK: - events
	// MARK: -

	func handleKey(_ key: String, flags: ZEventFlags) -> Bool {   // false means key not handled
		let  COMMAND = flags.isCommand
		let  SPECIAL = flags.exactlySpecial

		switch key {
			case "?", "/":         show(       flags: flags)
			case "w":              show(false, flags: flags)
			case "p":              view.printView()
			case "q":              gApplication?.terminate(self)
			case "a": if SPECIAL { gApplication?.showHideAbout() }
			case "r": if COMMAND { sendEmailBugReport() }
			default:  if  let arrow = key.arrow {
				switch arrow {
					case .left, .right: titleBarButtons.showNextHelp(forward: arrow == .right)
					default: return false
				}
			}
		}

		return true
	}

	func handleEvent(_ event: ZEvent) -> ZEvent? {
		if  let   key = event.key {
			let flags = event.modifierFlags
			return handleKey(key, flags: flags) ? nil : event
		}

		return nil
	}

	// MARK: - grid
	// MARK: -

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

	// MARK: - help table
    // MARK: -

	var clickCoordinates: (Int, Int)? {

		#if os(OSX)

		if  let              table = genericTableView,
			let                row = table.selectedRowIndexes.first {
			if  let       location = table.currentMouseLocation {
				let         column = Int(floor(location.x / CGFloat(helpData.columnWidth)))

				table.deselectRow(row)
				
				return (row, min(3, column))
			}
		}

		#endif
		
		return nil
	}

	override func numberOfRows(in tableView: ZTableView) -> Int {
		helpData.prepareStrings()

		return helpData.countOfRows
    }

	func tableViewSelectionIsChanging(_ notification: Notification) {
		if  let (row, column) = clickCoordinates, column >= 0,
			let hyperlink = helpData.url(for: row, column: column) {
			hyperlink.openAsURL()
		}
	}

}
