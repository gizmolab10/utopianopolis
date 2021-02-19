//
//  ZDebugController.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/18/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

var gDebugController: ZDebugController? { return gControllers.controllerForID(.idDebug) as? ZDebugController }

enum ZDebugID: Int {
	case dRegistry
	case dZones
	case dTraits
	case dMistype
	case dDuplicates
	case dEnd

	var title: String { return "\(self)".lowercased().substring(fromInclusive: 1) }
}

class ZDebugController: ZGenericTableController {
	override var controllerID : ZControllerID { return .idDebug }
	var                  rows : Int { return ZDebugID.dEnd.rawValue }

	#if os(OSX)

	override func numberOfRows(in tableView: ZTableView) -> Int { return rows }

	func tableView(_ tableView: ZTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		if  let columnTitle = tableColumn?.title,
			let     debugID = ZDebugID(rawValue: row) {

			switch columnTitle {
				case "0": return debugID.title
				default:  return "\(value(for: debugID))"
			}
		}

		return nil
	}

	func value(for debugID: ZDebugID) -> Int {
		switch debugID {
			case .dDuplicates: return gRecords?.duplicates         .count ?? 0
			case .dRegistry:   return gRecords?.zRecordsLookup     .count ?? 0
			case .dMistype:    return gRecords?.recordsMistyped    .count ?? 0
			case .dTraits:     return gRecords?.countBy(type: kTraitType) ?? 0
			case .dZones:      return gRecords?.countBy(type:  kZoneType) ?? 0
			default:           break
		}

		return 0
	}

	#endif
}
