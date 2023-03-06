//
//  ZRecents.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/18/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

//let gRecents     = ZRecents(ZDatabaseID.recentsID)
//var gRecentsRoot : Zone? { return gRecents.rootZone }
//var gRecentsHere : Zone? { return gRecentsHereMaybe ?? gRecentsRoot }
//
//var gRecentsHereMaybe: Zone? {
//	get { return gHereZoneForIDMaybe(       .recentsID) }
//	set { gSetHereZoneForID(here: newValue, .recentsID) }
//}

class ZRecents : ZSmallMapRecords {

	override var rootZone : Zone? {
		get {
			return gMineCloud?.recentsZone
		}

		set {
			gMineCloud?.recentsZone = newValue
		}
	}

	func setup(_ onCompletion: IntClosure?) {
		FOREGROUND { [self] in               // avoid error? mutating core data while enumerating
			rootZone = Zone.uniqueZone(recordName: kRecentsRootName, in: .mineID)

			if  gCDMigrationState != .normal {
				rootZone?.expand()
			}

			onCompletion?(0)
		}
	}

	// MARK: - focus
	// MARK: -

	@discardableResult func refocus(_ atArrival: @escaping Closure) -> Bool {
		if  let    current = currentRecent {
			return current.focusThrough(atArrival)
		}

		return false
	}

}
