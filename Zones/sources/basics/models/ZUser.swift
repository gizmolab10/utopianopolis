//
//  ZUser.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/26/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

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
	var                 isExempt: Bool { return authorID == "38AC7308-C627-4F83-B4E0-CAC3FFEAA142" }

	var access: ZUserAccess {
		if  isExempt {
			writeAccess  = NSNumber(value: ZUserAccess.eFull.rawValue)
		}
		
		if  writeAccess == nil {
			writeAccess  = NSNumber(value: ZUserAccess.eNormal.rawValue)
		}
		
		return ZUserAccess(rawValue: writeAccess!.intValue)!
	}

	static func uniqueUser(recordName: String?, in dbID: ZDatabaseID) -> ZUser {
		return uniqueZRecord(entityName: kUserType, recordName: recordName, in: dbID) as! ZUser
	}

	func save() {
		gUserRecordName = recordName
	}

    override var cloudProperties: StringsArray { return ZUser.cloudProperties }

    override class var cloudProperties: StringsArray {
        return [#keyPath(authorID),
                #keyPath(writeAccess),
                #keyPath(sentEmailType)] +
				super.cloudProperties
    }

}
