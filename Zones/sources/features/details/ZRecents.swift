//
//  ZRecents.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/18/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

enum ZFocusKind: Int {
	case eSelected
	case eEdited
}

let gRecents     = ZRecents(ZDatabaseID.recentsID)
var gRecentsRoot : Zone? { return gRecents.rootZone }
var gRecentsHere : Zone? { return gRecentsHereMaybe ?? gRecentsRoot }

var gRecentsHereMaybe: Zone? {
	get { return gHereZoneForIDMaybe(       .recentsID) }
	set { gSetHereZoneForID(here: newValue, .recentsID) }
}

class ZRecents : ZSmallMapRecords {

	var pushIsDisabled = false

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

		onCompletion?(0)
	}

	func disablePush(_ closure: Closure) {
		pushIsDisabled = true

		closure()

		pushIsDisabled = false
	}

	override func push(_ zone: Zone? = gHere, intoNotes: Bool = false) {
		if !pushIsDisabled,
		    rootZone != nil {
			var here  = zone

			if  intoNotes {
				here  = gCurrentEssayZone
			}

			if  gHasFinishedStartup, // avoid confusing recents upon relaunch
				let pushMe = here {
				let      _ = bookmarkTargeting(pushMe) ?? matchOrCreateBookmark(for: pushMe, autoAdd: true)
				updateCurrentRecent()
			}
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

	// MARK:- focus
	// MARK:-

	@discardableResult func refocus(_ atArrival: @escaping Closure) -> Bool {
		if  let    current = currentBookmark {
			return current.focusThrough(atArrival)
		}

		return false
	}

}
