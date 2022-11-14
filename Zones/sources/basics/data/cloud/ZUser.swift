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
    case eMaster
}

enum ZSentEmailType: String {
    case eBetaTesting = "t"
    case eProduction  = "p"
}

class ZUser : ZRecord {

    @objc dynamic var      authorID: String?   { didSet { save() } }
    @objc dynamic var   writeAccess: NSNumber? { didSet { save() } }
	@objc dynamic var sentEmailType: String?   { didSet { if oldValue != sentEmailType { save() } } }

    var access: ZUserAccess {
        get {
            updateInstanceProperties()

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
