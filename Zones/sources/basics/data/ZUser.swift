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

var gUser              : ZUser?
var gUserHasFullAccess : Bool { return (gUser?.userAccess ?? .eNormal) == .eFull }

@objc(ZUser)
class ZUser : ZRecord {

	@NSManaged var        authorID : String?
	@NSManaged var   sentEmailType : String?
	@NSManaged var     writeAccess : NSNumber?
	override   var cloudProperties : StringsArray { return ZUser.cloudProperties }

	var userAccess: ZUserAccess? {
		var access = writeAccess?.userAccess

		var hasMasterKey : Bool {                                    // authorID == "783BF01A-7535-4950-99EE-B63DB2732824"
			return recordName == "_925d8acf4e622d5eca4d33938a6cc07e"

			// /////////////////////////////////// //
			//        previous record names        //
			//                                     //
			//  _8b4d2b5f3c5307d20e3d5da52be62689  //
			//  _bd0f258c61806cc7232118700c46914c  //
			// /////////////////////////////////// //
		}

		if  hasMasterKey {
			access = .eFull
		} else if writeAccess == nil {
			access = .eNormal
		}

		writeAccess = access?.number
		
		return access
	}

	static func createUser(from recordName: String) {

		// //////////////////////////////////////////// //
		// persist for file read on subsequent launch   //
		//   also: for determining write permission     //
		//   also: for core data latest store location  //
		// //////////////////////////////////////////// //

		gUser               = uniqueUser(recordName: recordName, in: gDatabaseID)
		gCloudAccountStatus = .active

		// ////////////////////////// //
		// ONBOARDING IS NOW COMPLETE //
		// ////////////////////////// //

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

enum ZUserAccess: Int {
	case eNormal
	case eFull

	var number : NSNumber { return NSNumber(value: rawValue) }
}

enum ZSentEmailType: String {
	case eBetaTesting = "t"
	case eProduction  = "p"
}

extension NSNumber {
	var userAccess: ZUserAccess? { return ZUserAccess(rawValue: intValue) }
}
