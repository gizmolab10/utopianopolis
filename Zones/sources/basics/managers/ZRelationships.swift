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

			array.appendUniqueRelationship(relationship)

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

	@discardableResult func addUniqueRelationship(_ zone: Zone, parent: Zone?, in databaseID: ZDatabaseID) -> ZRelationship? {
		if  let           from = zone   .asString,
			let             to = parent?.asString {
			let   relationship = ZRelationship.uniqueRelationship(in: databaseID) // this crashes
			relationship?.from = from
			relationship?  .to = to

			addRelationship(relationship)

			return relationship
		}

		return nil
	}

	func addOrSwapRelationship(_ zone: Zone, parent: Zone?, priorParent: Zone?, in databaseID: ZDatabaseID) {
		if !swapRelationship     (zone, parent: parent, priorParent: priorParent, in: databaseID) {
			addUniqueRelationship(zone, parent: parent,                           in: databaseID)
		}
	}

	func swapRelationship(_ zone: Zone, parent: Zone?, priorParent: Zone?, in databaseID: ZDatabaseID) -> Bool {
		if  let prior         = priorParent,
			var relationships = relationshipsFor(zone) {
			let replacement   = parent?.asString
			var removeMe      : Int?

			for (index, relationship) in relationships.enumerated() {
				if  relationship.parent == prior {
					if  let r = replacement {
						relationship.to = r

						return true
					} else {
						removeMe = index           // can't mutate during enumerate

						break
					}
				}
			}

			if  let index = removeMe,
				let  dbid = zone.dbid,
				let   key = zone.recordName {
				let     r = relationships[index]

				relationships.remove(at: index)    // mutate
				gCDCurrentBackgroundContext?.delete(r)

				lookup[dbid]?[key] = relationships

				return true
			}
		}

		return false
	}

}

extension ZRelationshipArray {

	@discardableResult mutating func appendUniqueRelationship(_ relationship: ZRelationship?) -> Bool {
		if  let r = relationship {
			return appendUnique(item: r) { (a, b) -> (Bool) in
				if  let    ar  = (a as? ZRelationship),
					let    br  = (b as? ZRelationship) {
					return ar.from == br.from && ar.to == br.to
				}

				return false
			}
		}

		return false
	}

}
