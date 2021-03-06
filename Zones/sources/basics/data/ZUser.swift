//
//  ZUser.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/26/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit

enum ZUserAccess: Int {
    case eNormal
    case eFull
}

enum ZSentEmailType: String {
    case eBetaTesting = "t"
    case eProduction  = "p"
}

@objc(ZUser)
class ZUser : ZRecord {

	@NSManaged var      authorID: String?
	@NSManaged var   writeAccess: NSNumber?
	@NSManaged var sentEmailType: String?

	var access: ZUserAccess {
        get {
			if  authorID    == "38AC7308-C627-4F83-B4E0-CAC3FFEAA142" {
				writeAccess  = NSNumber(value: ZUserAccess.eFull.rawValue)
			}

            if  writeAccess == nil {
                writeAccess  = NSNumber(value: ZUserAccess.eNormal.rawValue)
            }

            return ZUserAccess(rawValue: writeAccess!.intValue)!
        }

        set {
			writeAccess = NSNumber(value: newValue.rawValue)
        }
    }

	func save() {
		updateCKRecordProperties()

		gUserRecord = self.ckRecord

		needSave()
	}

	static func create(record: CKRecord, databaseID: ZDatabaseID?) -> ZUser {
		if  let    has = hasMaybe(record: record, entityName: kUserEntityName, databaseID: databaseID) as? ZUser {        // first check if already exists
			return has
		}

		return ZUser.init(record: record, databaseID: databaseID)
	}

    override var cloudProperties: [String] { return ZUser.cloudProperties }

    override class var cloudProperties: [String] {
        return [#keyPath(authorID),
                #keyPath(writeAccess),
                #keyPath(sentEmailType)] +
				super.cloudProperties
    }

}
