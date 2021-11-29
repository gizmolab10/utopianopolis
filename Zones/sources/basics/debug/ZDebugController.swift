//
//  ZDebugController.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/18/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

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
	case bBoxes

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
		if  let columnTitle = tableColumn?.title {
			let     debugID = ZDebugID     (rawValue: row)
			let     thingID = ZDebugThingID(rawValue: row)
			var      string : String? = nil
			switch columnTitle {
				case "title": string = debugID?.title
				case "value": string = "\(gRecords?.debugValue(for: debugID) ?? 0)"
				default:      string = thingID?.title
			}

			return string
		}

		return nil
	}

	func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
		if  let     thingID = ZDebugThingID(rawValue: row),
			let columnTitle = tableColumn?.title,
			columnTitle    == "thing" {
			handleThingAction(thingID)
		}

		return false
	}

	func handleThingAction(_ thingID: ZDebugThingID) {
		gToggleDebugMode(.dDebugDraw)
		gRelayoutMaps()
	}

	#endif
}
