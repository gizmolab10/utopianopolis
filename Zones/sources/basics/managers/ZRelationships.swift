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

	var lookup = [String : ZRelationshipsDictionary]()

	func addRelationship(_ relationship: ZRelationship?) {
		if  let     from = relationship?.from,
			let     dbid = from.maybeDatabaseID?.identifier,
			let      key = from.maybeRecordName {
			var     dict = lookup[dbid] ?? ZRelationshipsDictionary()
			var    array = dict   [key] ?? ZRelationshipArray()

			if  dbid    == "e" {
				noop()
			}

			array.appendUnique(item: relationship)

			dict   [key] = array
			lookup[dbid] = dict
		}
	}

	func relationshipsFor(_ zone: Zone) -> ZRelationshipArray? {
		if  let  key = zone.asString?.maybeRecordName,
			let dbid = zone.dbid,
			let dict = lookup[dbid] {
			return dict[key]
		}

		return nil
	}

}

extension ZRelationshipArray {

	@discardableResult mutating func appendUnique(item: ZRelationship) -> Bool {
		return appendUnique(item: item) { (a, b) -> (Bool) in
			if  let    ar  = (a as? ZRelationship),
				let    br  = (b as? ZRelationship) {
				return ar.from == br.from && ar.to == br.to
			}

			return false
		}
	}

}
