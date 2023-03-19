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

	var        lookup = ZDBIDRelationsDictionary()
	var reverseLookup = ZDBIDRelationsDictionary()
	func        relationshipsFor(_ zone: Zone) -> ZRelationshipArray? { return !gHasRelationships ? nil : relationshipsFor(zone, within:        lookup) }
	func reverseRelationshipsFor(_ zone: Zone) -> ZRelationshipArray? { return !gHasRelationships ? nil : relationshipsFor(zone, within: reverseLookup) }

	@discardableResult func addBookmarkRelationship(_ bookmark: Zone?, target: Zone?, in databaseID: ZDatabaseID) -> ZRelationship? {
		return !gBookmarkAsRelations ? nil : addUniqueRelationship(type: .bookmark, from: target, relative: bookmark, in: databaseID)
	}

	@discardableResult func addParentRelationship(_ zone: Zone?, parent: Zone?, in databaseID: ZDatabaseID) -> ZRelationship? {
		return addUniqueRelationship(type: .parent, from: zone, relative: parent, in: databaseID)
	}

	@discardableResult func addUniqueRelationship(type: ZRelationType, from zone: Zone?, relative: Zone?, in databaseID: ZDatabaseID) -> ZRelationship? {
		if  gHasRelationships,
			let                     to = relative?.asString,
			let                   from = zone?    .asString {
			let           relationship = ZRelationship.uniqueRelationship(in: databaseID)
			relationship?.relationType = type
			relationship?        .from = from
			relationship?          .to = to

			addRelationship(relationship)

			return relationship
		}

		return nil
	}

	func addRelationship(_ relationship: ZRelationship?) {
		if  let           to = relationship?.to,
			let         from = relationship?.from,
			let         dbid = from.maybeDatabaseID?.identifier,
			let          key = from.maybeRecordName,
			let  reverseDbid = to  .maybeDatabaseID?.identifier,
			let   reverseKey = to  .maybeRecordName {
			var         dict = lookup           [dbid] ?? ZRelationshipsDictionary()
			var  reverseDict = lookup    [reverseDbid] ?? ZRelationshipsDictionary()
			var        array = dict              [key] ?? ZRelationshipArray()
			var reverseArray = reverseDict[reverseKey] ?? ZRelationshipArray()

			array       .appendUniqueRelationship(relationship)
			reverseArray.appendUniqueRelationship(relationship)

			dict                 [key] = array
			reverseDict   [reverseKey] = reverseArray
			lookup              [dbid] = dict
			reverseLookup[reverseDbid] = reverseDict
		}
	}

	func relationshipsFor(_ zone: Zone, within dbidLookup: ZDBIDRelationsDictionary) -> ZRelationshipArray? {
		if  let dbid = zone.dbid,
			let  key = zone.recordName,
			let dict = dbidLookup[dbid] {
			return dict[key]
		}

		return nil
	}

	func addOrSwapParentRelationship(_ zone: Zone, parent: Zone?, priorParent: Zone?, in databaseID: ZDatabaseID) {
		if  gHasRelationships,
			!swapParentRelationship(zone, parent: parent, priorParent: priorParent, in: databaseID) {
			addParentRelationship  (zone, parent: parent,                           in: databaseID)
		}
	}

	func swapParentRelationship(_ zone: Zone, parent: Zone?, priorParent: Zone?, in databaseID: ZDatabaseID) -> Bool {
		if  gHasRelationships,
			let prior         = priorParent,
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

	var parent: Zone? {
		for relationship in self {
			if  relationship.isParent {
				return relationship.parent
			}
		}

		return nil
	}

	var bookmarks: ZoneArray? {
		var results: ZoneArray?
		for relationship in self {
			if  relationship.isBookmark,
				let bookmark = relationship.bookmark {
				if  results == nil {
					results  = ZoneArray()
				}

				results?.append(bookmark)
			}
		}

		return results
	}

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
