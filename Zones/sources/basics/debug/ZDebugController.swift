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

class ZDebugController: ZGenericTableController {
	override var controllerID : ZControllerID { return .idDebug }
	var                  rows : Int { return ZDebugID.dEnd.rawValue }

	override func shouldHandle(_ kind: ZSignalKind) -> Bool {
		return super.shouldHandle(kind) && gDebugInfo
	}

	#if os(OSX)

	override func numberOfRows(in tableView: ZTableView) -> Int { return rows }

	func tableView(_ tableView: ZTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		if  let columnTitle = tableColumn?.title,
			let     debugID = ZDebugID(rawValue: row) {

			switch columnTitle {
				case "0": return debugID.title
				default:  return "\(gRecords?.debugValue(for: debugID) ?? 0)"
			}
		}

		return nil
	}

	#endif
}
