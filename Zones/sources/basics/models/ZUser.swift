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

	@objc dynamic var      authorID: String?   { didSet { if let o = oldValue, o != authorID      { save() } } }
	@objc dynamic var   writeAccess: NSNumber? { didSet { if let o = oldValue, o != writeAccess   { save() } } }
	@objc dynamic var sentEmailType: String?   { didSet { if let o = oldValue, o != sentEmailType { save() } } }

	var access: ZUserAccess {
        get {
            updateInstanceProperties()

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

		gUserRecord = self.record

		needSave()
	}

    override var cloudProperties: [String] { return ZUser.cloudProperties }

    override class var cloudProperties: [String] {
        return [#keyPath(authorID),
                #keyPath(writeAccess),
                #keyPath(sentEmailType)] +
				super.cloudProperties
    }

}
