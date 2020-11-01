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

	@discardableResult func pop(_ iZone: Zone? = gHereMaybe) -> Bool {
		if  let name = iZone?.recordName() {
			for bookmark in workingBookmarks {
				if  name == bookmark.bookmarkTarget?.recordName() {
					go(down: gListsGrowDown) {
						bookmark.deleteSelf(permanently: true) {}
					}

					return true

				}
			}
		}

		return false
	}

	func setHereAsParentOfBookmarkTargeting(_ target: Zone?) -> Bool {
		var found = false

		rootZone?.traverseProgeny { (bookmark) -> (ZTraverseStatus) in
			if  !found, // keep looking
				let targetName = bookmark.bookmarkTarget?.recordName(),
				targetName    == target?.recordName(),
				let     parent = bookmark.parentZone {

				hereZoneMaybe  = parent
				found          = true

				return .eStop
			}

			return .eContinue
		}

		return !found
	}

	func push(intoNotes: Bool = false) {
		if  rootZone != nil {
			if  setHereAsParentOfBookmarkTargeting(gHereMaybe),
				let bookmark = gFavorites.createFavorite(for: gHereMaybe, action: .aBookmark) {
				var    index = gListsGrowDown ? nil : 0                // assume current bookmark's parent is NOT current here

				if  let          b = currentBookmark,
					let          p = b.parentZone,
					hereZoneMaybe == p,                                // current bookmark's parent same as here
					let sIndex     = b.siblingIndex {
					index          = sIndex + (gListsGrowDown ? 1 : 0) // place new bookmark relative to current one
				}

				bookmark.moveZone(into: currentHere, at: index)
			}

			updateCurrentRecent()
		}
	}

	func popAndUpdateRecents(){
		if  !pop(),
		    workingBookmarks.count > 0 {
			currentBookmark = workingBookmarks[0]
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
