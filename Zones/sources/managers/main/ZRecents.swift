//
//  ZRecents.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/18/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

let gRecents = ZRecents(ZDatabaseID.recentsID)

var gRecentsRoot : Zone? {
	get {
		return gMineCloud?.recentsZone
	}

	set {
		if  let n = newValue {
			gMineCloud?.recentsZone = n
		}
	}
}

class ZRecents: ZRecords {

	var currentRecent: Zone?

	func updateCurrentRecent() {
		if  let           bookmark = gRecentsRoot?.children.bookmarksTargeting(gHereMaybe) {
			gRecents.currentRecent = bookmark
		}
	}

	func setup(_ onCompletion: IntClosure?) {
		let         mine = gMineCloud
		if  let     root = mine?.maybeZoneForRecordName(kRecentsRootName) {
			gRecentsRoot = root

			gRecentsRoot?.reallyNeedProgeny()
			onCompletion?(0)
		} else {
			mine?.assureRecordExists(withRecordID: CKRecord.ID(recordName: kRecentsRootName), recordType: kZoneType) { (iRecord: CKRecord?) in
				let      ckRecord = iRecord ?? CKRecord(recordType: kZoneType, recordID: CKRecord.ID(recordName: kRecentsRootName))
				let          root = Zone(record: ckRecord, databaseID: .mineID)
				root.directAccess = .eProgenyWritable
				root.zoneName     = kRecentsRootName
				gRecentsRoot      = root

				gRecentsRoot?.reallyNeedProgeny()
				onCompletion?(0)
			}
		}
	}

	func push() {
		if  let root = gRecentsRoot {
			for bookmark in root.children {
				if  let target = bookmark.bookmarkTarget,
					target.recordName() == gHere.recordName() {
					return
				}
			}

			if  let bookmark = gFavorites.createBookmark(for: gHereMaybe, style: .addFavorite) {
				root.children.append(bookmark)
			}

			updateCurrentRecent()
		}
	}

}
