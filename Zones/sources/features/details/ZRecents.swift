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

let gRecents = ZRecents(ZDatabaseID.recentsID)
var gRecentsRoot : Zone? { return gRecents.root }
var gRecentsHere : Zone? { return gRecentsHereMaybe ?? gRecentsRoot }

class ZRecents : ZRecords {

	var currentRecent: Zone?

	var root : Zone? {
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
		let        mine = gMineCloud
		if  let newRoot = mine?.maybeZoneForRecordName(kRecentsRootName) {
			root        = newRoot

			newRoot.reallyNeedProgeny()
			onCompletion?(0)
		} else {
			mine?.assureRecordExists(withRecordID: CKRecord.ID(recordName: kRecentsRootName), recordType: kZoneType) { (iRecord: CKRecord?) in
				let            ckRecord = iRecord ?? CKRecord(recordType: kZoneType, recordID: CKRecord.ID(recordName: kRecentsRootName))
				self.root               = Zone(record: ckRecord, databaseID: .mineID)
				self.root?.directAccess = .eProgenyWritable
				self.root?.zoneName     = kRecentsRootName

				self.root?.reallyNeedProgeny()
				onCompletion?(0)
			}
		}
	}

	func updateRecents(shouldGrab: Bool = false) {
		if  currentRecent?.isGrabbed ?? false {
			currentRecent?.bookmarkTarget?.grab()
		} else if updateCurrentRecent(),
				  shouldGrab,
				  gIsRecentlyMode {
			currentRecent?.grab()
		}
	}

	@discardableResult func updateCurrentRecent() -> Bool {
		if  let recents = root?.allBookmarkProgeny {
			var targets = ZoneArray()

			if  let grab = gSelecting.firstGrab {
				targets.append(grab)
			}

			if  let here = gHereMaybe {
				targets.appendUnique(contentsOf: [here])
			}

			if  let bookmark  = recents.bookmarksTargeting(targets) {
				currentRecent = bookmark

				return true
			}
		}

		return false
	}

	func push(intoNotes: Bool = false) {
		if  let r = root {
			var done = false

			r.traverseAllProgeny { bookmark in
				if  done    == false,
					let name = bookmark.bookmarkTarget?.recordName(),
					name    == gHereMaybe?.recordName() {

					done = true
				}
			}

			if  done == false,
			    let bookmark = gFavorites.createBookmark(for: gHereMaybe, action: .aBookmark) {
				bookmark.moveZone(to: r)
			}

			updateCurrentRecent()
		}
	}

	@discardableResult func pop(fromNotes: Bool = false) -> Bool {
		return remove(gHereMaybe, fromNotes: fromNotes)
	}

	@discardableResult func remove(_ iItem: NSObject?, fromNotes: Bool = false) -> Bool {
		if  let  zone = iItem as? Zone,
			let     r = root {
			var found = kCFNotFound

			for (index, bookmark) in r.children.enumerated() {
				if  let name = bookmark.bookmarkTarget?.recordName(),
					name    == zone.recordName() {
					found    = index

					break
				}
			}

			if  found != kCFNotFound {
				go(forward: true)
				r.children.remove(at: found)

				return true
			}
		}

		return false
	}

	func go(forward: Bool, amongNotes: Bool = false) {
		if  let progeny = root?.allBookmarkProgeny {
			let     max = progeny.count - 1

			for (index, recent) in progeny.enumerated() {
				if  recent   == currentRecent {
					var found = 0

					if  forward {
						if  index < max {
							found = index + 1
						}
					} else if  index == 0 {
						found = max
					} else {
						found = index - 1
					}

					setCurrent(progeny[found])

					break
				}
			}
		}
	}

	func setCurrent(_ recent: Zone) {
		currentRecent   = recent
		if  let   pHere = recent.parentZone,
			recentHere != pHere {
			recentHere.concealChildren()

			recentHere  = pHere

			recentHere.revealChildren()
		}

		if  let tHere = recent.bookmarkTarget {
			gHere     = tHere

			focusKind(.eSelected) {
				gHere.grab()
				gSignal([.sRelayout])
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
		if  let    current = currentRecent {
			return current.focusThrough(atArrival)
		}

		return false
	}

	func focusKind(_ kind: ZFocusKind = .eEdited, _ COMMAND: Bool = false, shouldGrab: Bool = false, _ atArrival: @escaping Closure) {

		// regarding grabbed/edited zone, five states:
		// 1. is a bookmark      -> target becomes here
		// 2. is here            -> update in favorites, not push
		// 3. in favorite/recent -> grab here
		// 4. not here, COMMAND  -> become here
		// 5. not COMMAND        -> select here

		guard  let zone = (kind == .eEdited) ? gCurrentlyEditingWidget?.widgetZone : gSelecting.firstSortedGrab else {
			atArrival()

			return
		}

		let finishAndGrab = { (iZone: Zone) in
			gFavorites.updateCurrentFavorite()
			iZone.grab()
			atArrival()
		}

		if  zone.isBookmark {     		// state 1
			zone.travelThrough() { object, kind in
				gHere = object as! Zone

				finishAndGrab(gHere)
			}
		} else if zone == gHere {       // state 2
			gRecents.updateRecents(shouldGrab: shouldGrab)
			gFavorites.updateGrab()
			atArrival()
		} else if !zone.isInMap {       // state 3
			finishAndGrab(gHere)
		} else if COMMAND {             // state 4
			gRecents.refocus {
				atArrival()
			}
		} else {                        // state 5
			if  shouldGrab {
				gHere = zone
			}

			finishAndGrab(zone)
		}
	}

}
