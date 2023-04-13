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

	var number : NSNumber { return NSNumber(value: rawValue) }
}

enum ZSentEmailType: String {
    case eBetaTesting = "t"
    case eProduction  = "p"
}

@objc(ZUser)
class ZUser : ZRecord {

	@NSManaged var        authorID : String?
	@NSManaged var   sentEmailType : String?
	@NSManaged var     writeAccess : NSNumber?
	override   var cloudProperties : StringsArray { return ZUser.cloudProperties }
	var                   isExempt : Bool         { return recordName == "_8b4d2b5f3c5307d20e3d5da52be62689" } // authorID == "783BF01A-7535-4950-99EE-B63DB2732824" }
	func       persistRecordName()                { gUserRecordName = recordName }

	var access: ZUserAccess {
		if  isExempt {
			writeAccess = ZUserAccess.eFull.number
		} else if writeAccess == nil {
			writeAccess = ZUserAccess.eNormal.number
		}
		
		return ZUserAccess(rawValue: writeAccess!.intValue)!
	}

	static func uniqueUser(recordName: String?, in databaseID: ZDatabaseID) -> ZUser {
		return uniqueZRecord(entityName: kUserType, recordName: recordName, in: databaseID, checkCDStore: true) as! ZUser
	}

    override class var cloudProperties: StringsArray {
        return [#keyPath(authorID),
                #keyPath(writeAccess),
                #keyPath(sentEmailType)] +
				super.cloudProperties
    }

}
