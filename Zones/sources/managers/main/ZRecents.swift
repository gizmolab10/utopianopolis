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

	func setup(_ onCompletion: IntClosure?) {
		let   mine = gMineCloud
		let finish = {
			if  let root = gRecentsRoot {
				root.reallyNeedProgeny()
			}

			onCompletion?(0)
		}

		if  let root = mine?.maybeZoneForRecordName(kRecentsRootName) {
			gRecentsRoot = root

			finish()
		} else {
			mine?.assureRecordExists(withRecordID: CKRecord.ID(recordName: kRecentsRootName), recordType: kZoneType) { (iRecord: CKRecord?) in
				let      ckRecord = iRecord ?? CKRecord(recordType: kZoneType, recordID: CKRecord.ID(recordName: kRecentsRootName))
				let          root = Zone(record: ckRecord, databaseID: .mineID)
				root.directAccess = .eProgenyWritable
				root.zoneName     = kRecentsRootName
				gRecentsRoot      = root

				finish()
			}
		}
	}

	func push() {
		gRecentsRoot?.children.append(gHere)
	}

}
