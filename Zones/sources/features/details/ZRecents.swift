//
//  ZRecents.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/18/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

let gRecents     = ZRecents(ZDatabaseID.recentsID)
var gRecentsRoot : Zone? { return gRecents.rootZone }
var gRecentsHere : Zone? { return gRecentsHereMaybe ?? gRecentsRoot }

var gRecentsHereMaybe: Zone? {
	get { return gHereZoneForIDMaybe(       .recentsID) }
	set { gSetHereZoneForID(here: newValue, .recentsID) }
}

class ZRecents : ZSmallMapRecords {

	override var rootZone : Zone? {
		get {
			return gMineCloud?.recentsZone
		}

		set {
			if  let n = newValue {
				gMineCloud?.recentsZone = n
			}
		}
	}

	func setup(_ onCompletion: IntClosure?) {
		rootZone = Zone.uniqueZone(recordName: kRecentsRootName, in: .mineID)

		if  gCDMigrationState != .normal {
			rootZone?.expand()
		}

		onCompletion?(0)
	}

	override func push(_ zone: Zone? = gHere) {
		if !gPushIsDisabled,
		    gHasFinishedStartup, // avoid confusing recents upon relaunch
		    rootZone != nil,
			let pushMe = zone {

			if  bookmarkTargeting(pushMe) == nil {
				matchOrCreateBookmark(for: pushMe, autoAdd: true)
			}

			updateCurrentBookmark()
		}
	}

	func object(for id: String) -> NSObject? {
		let parts = id.components(separatedBy: kColonSeparator)

		if  parts.count == 2 {
			if  parts[0] == "note" {
				return ZNote .object(for: parts[1], isExpanded: false)
			} else {
				return ZEssay.object(for: parts[1], isExpanded: true)
			}
		}

		return nil
	}

	// MARK: - focus
	// MARK: -

	@discardableResult func refocus(_ atArrival: @escaping Closure) -> Bool {
		if  let    current = currentBookmark {
			return current.focusThrough(atArrival)
		}

		return false
	}

}
