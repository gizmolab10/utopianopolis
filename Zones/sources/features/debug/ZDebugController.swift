//
//  ZDebugController.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/18/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

enum ZDebugID: Int {
	case dRegistry
	case dTotal
	case dZones
	case dValid
	case dProgeny
	case dTrash
	case dFavorites
	case dRecents
	case dLost
	case dTraits
	case dDestroy
	case dDuplicates
	case dEnd

	var title: String { return "\(self)".lowercased().substring(fromInclusive: 1) }
}

enum ZDebugThingID: Int {
	case tBoxes
	case tAngles

	var title: String { return "\(self)".lowercased().substring(fromInclusive: 1) }
}

class ZDebugController: ZGenericTableController {
	override var controllerID : ZControllerID { return .idDebug }
	var                  rows : Int { return ZDebugID.dEnd.rawValue }

	override func awakeFromNib() {
		super.awakeFromNib()

		genericTableView?.delegate = self
	}

	override func shouldHandle(_ kind: ZSignalKind) -> Bool {
		return super.shouldHandle(kind) && gDebugInfo
	}

#if os(OSX)

	override func numberOfRows(in tableView: ZTableView) -> Int {
		return gDebugInfo ? rows : 0
	}

	func tableView(_ tableView: ZTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		if  let columnTitle = tableColumn?.title,
			let     debugID = ZDebugID(rawValue: row) {
			var      string : String? = nil
			switch columnTitle {
				case "title": string = debugID.title
				case "value": string = "\(gRecords.debugValue(for: debugID) ?? 0)"
				default:      break
			}

			return string
		}

		return nil
	}

	func thing(for row: Int) -> ZControl? {
		if  let       thingID = ZDebugThingID(rawValue: row) {
			let          rect = CGRect(origin: .zero, size: CGSize(width: 40.0, height: 18.0))
			let        button = ZButton(frame: rect)
			button    .action = #selector(handleThingAction)
			button     .state = state(for: thingID)
			button       .tag = thingID.rawValue
			button     .title = thingID.title
			button      .font = gMicroFont
			button.isBordered = false
			button    .target = self

			button.setButtonType(.toggle)

			return button
		}

		return nil
	}

	func tableView(_ tableView: ZTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		if  tableColumn?.title == "thing" {
			return thing(for: row)
		} else if let string = self.tableView(tableView, objectValueFor: tableColumn, row: row) as? String {
			let         text = ZTextField(labelWithString: string)
			text       .font = gMicroFont
			text .isBordered = false

			return text
		}

		return nil
	}

	func state(for thingID: ZDebugThingID) -> NSControl.StateValue {
		var flag = false

		switch thingID {
			case .tBoxes:  flag = gDebugDraw
			case .tAngles: flag = gDebugAngles
		}

		return flag ? .on : .off
	}

	@objc func handleThingAction(_ thing: ZControl?) {
		if  let        tag = thing?.tag,
			let    thingID = ZDebugThingID(rawValue: tag) {
			switch thingID {
				case .tBoxes:  gToggleDebugMode(.dDebugDraw)
				case .tAngles: gToggleDebugMode(.dDebugAngles); gSignal([.spMain])
			}

			gRelayoutMaps()
		}
	}

#endif

}
