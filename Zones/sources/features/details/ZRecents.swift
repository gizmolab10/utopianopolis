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
var gRecentsRoot : Zone? { return gRecents.rootZone }
var gRecentsHere : Zone? { return gRecentsHereMaybe ?? gRecentsRoot }

class ZRecents : ZRecords {

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
		let        mine = gMineCloud
		if  let newRoot = mine?.maybeZoneForRecordName(kRecentsRootName) {
			rootZone    = newRoot

			newRoot.reallyNeedProgeny()
			onCompletion?(0)
		} else {
			mine?.assureRecordExists(withRecordID: CKRecord.ID(recordName: kRecentsRootName), recordType: kZoneType) { (iRecord: CKRecord?) in
				let                ckRecord = iRecord ?? CKRecord(recordType: kZoneType, recordID: CKRecord.ID(recordName: kRecentsRootName))
				self.rootZone               = Zone(record: ckRecord, databaseID: .mineID)
				self.rootZone?.directAccess = .eProgenyWritable
				self.rootZone?.zoneName     = kRecentsRootName

				self.rootZone?.reallyNeedProgeny()
				onCompletion?(0)
			}
		}
	}

	func updateRecents(shouldGrab: Bool = false) {
		if  currentBookmark?.isGrabbed ?? false {
			currentBookmark?.bookmarkTarget?.grab()
		} else if updateCurrentRecent(),
				  shouldGrab,
				  gIsRecentlyMode {
			currentBookmark?.grab()
		}
	}

	@discardableResult func updateCurrentRecent() -> Bool {
		if  let recents = rootZone?.allBookmarkProgeny {
			var targets = ZoneArray()

			if  let grab = gSelecting.firstGrab {
				targets.append(grab)
			}

			if  let here = gHereMaybe {
				targets.appendUnique(contentsOf: [here])
			}

			if  let bookmark    = recents.bookmarksTargeting(targets) {
				currentBookmark = bookmark

				return true
			}
		}

		return false
	}

	func push(intoNotes: Bool = false) {
		if  let r = rootZone {
			var done = false

			r.traverseAllProgeny { bookmark in
				if  done    == false,
					let name = bookmark.bookmarkTarget?.recordName(),
					name    == gHereMaybe?.recordName() {

					done = true
				}
			}

			if  done == false,
			    let bookmark = gFavorites.createFavorite(for: gHereMaybe, action: .aBookmark) {
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
			let     r = rootZone {

			for (index, bookmark) in r.children.enumerated() {
				if  let name = bookmark.bookmarkTarget?.recordName(),
					name    == zone.recordName() {

					go(forward: true) {
						r.children.remove(at: index)
					}

					return true

				}
			}
		}

		return false
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
