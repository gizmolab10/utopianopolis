//
//  ZManagedRecord.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

class ZManagedRecord: NSManagedObject {

	convenience init(record: CKRecord?) {
		if  let n = record?.entityName,
			let c = gDesktopAppDelegate?.managedContext,
			let e = NSEntityDescription.entity(forEntityName: n, in: c) {
			self.init(entity: e, insertInto: c)
		} else {
			self.init()
		}
	}

}
