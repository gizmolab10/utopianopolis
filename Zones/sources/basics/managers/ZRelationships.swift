//
//  ZRelationships.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/16/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

let gRelationships = ZRelationships()

class ZRelationships: NSObject {

	var lookup = [String : [ZRelationship]]()

	func addRelationship(_ relationship: ZRelationship) {
		if  let     key = relationship.from {
			var   array = lookup[key] ?? [ZRelationship]()

			array.appendUnique(item: relationship)

			lookup[key] = array
		}
	}

	func relationshipsFor(_ zone: Zone) -> [ZRelationship]? {
		if  let key = zone.asString {
			return lookup[key]
		}

		return nil
	}

}
