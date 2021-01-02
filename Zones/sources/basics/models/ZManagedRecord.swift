//
//  ZManagedRecord.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZManagedRecord: NSManagedObject {

	convenience init(entityName: String?) {
		if  let    name = entityName,
			let context = gManagedContext,
			let  entity = NSEntityDescription.entity(forEntityName: name, in: context) {
			self.init(entity: entity, insertInto: context)
		} else {
			self.init()
		}
	}

}
