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

	var lookup = ZRelationshipsDictionary()

	@discardableResult func addParentRelationship(_ zone: Zone?, parent: Zone?, in databaseID: ZDatabaseID) -> ZRelationship? {
		return addUniqueRelationship(type: .parent, from: zone, relative: parent, in: databaseID)
	}

	@discardableResult func addBookmarkRelationship(_ bookmark: Zone?, target: Zone?, in databaseID: ZDatabaseID) -> ZRelationship? {
		return addUniqueRelationship(type: .target, from: bookmark, relative: target, in: databaseID)
	}

	@discardableResult func addBookmarkRelationship(for bookmark: Zone, targetNamed: String, in databaseID: ZDatabaseID) -> ZRelationship? {
		return addUniqueRelationship(type: .target, fromString: bookmark.linkAsString, relativeString: targetNamed, in: databaseID)
	}

	@discardableResult func addUniqueRelationship(type: ZRelationType, from zone: Zone?, relative: Zone?, in databaseID: ZDatabaseID) -> ZRelationship? {
		return addUniqueRelationship(type: type, fromString: zone?.linkAsString, relativeString: relative?.linkAsString, in: databaseID)
	}

	@discardableResult func addUniqueRelationship(type: ZRelationType, fromString: String?, relativeString: String?, in databaseID: ZDatabaseID) -> ZRelationship? {
		if  gCDUseRelationships,
			let                     to = relativeString,
			let                   from = fromString, to != from {
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
			let         from = relationship!.from {
			let       toHash = to  .hash
			let     fromHash = from.hash
			var      toZones = lookup  [toHash] ?? ZRelationshipArray()
			var    fromZones = lookup[fromHash] ?? ZRelationshipArray()

			fromZones.appendUniqueRelationship(relationship)
			toZones  .appendUniqueRelationship(relationship?.opposite)

			lookup  [toHash] =   toZones
			lookup[fromHash] = fromZones
		}
	}

	func relationshipsFor(_ zone: Zone) -> ZRelationshipArray? {
		if  gCDUseRelationships,
			let key = zone.linkAsString?.hash {
			return lookup[key]
		}

		return nil
	}

	func addOrSwapParentRelationship(_ zone: Zone, parent: Zone?, priorParent: Zone?, in databaseID: ZDatabaseID) {
		if  gCDUseRelationships,
			!swapParentRelationship(zone, parent: parent, priorParent: priorParent) {
			addParentRelationship  (zone, parent: parent, in: databaseID)
		}
	}

	func swapParentRelationship(_ zone: Zone, parent: Zone?, priorParent: Zone?) -> Bool {
		if  let prior         = priorParent,
			var relationships = relationshipsFor(zone) {
			let replacement   = parent?.linkAsString
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
				let   key = zone.linkAsString?.hash {
				let     r = relationships[index]

				relationships.remove(at: index)    // mutate
				r.deleteFromCD()

				lookup[key] = relationships

				return true
			}
		}

		return false
	}

}

extension ZRelationshipArray {

	var children  : ZoneArray? { return apply { relationship in return (relationship.relationType != .child)    ? nil : relationship.toZone } }
	var parents   : ZoneArray? { return apply { relationship in return (relationship.relationType != .parent)   ? nil : relationship.toZone } }
	var targets   : ZoneArray? { return apply { relationship in return (relationship.relationType != .target)   ? nil : relationship.toZone } }
	var bookmarks : ZoneArray? { return apply { relationship in return (relationship.relationType != .bookmark) ? nil : relationship.toZone } }

	func apply(_ closure: ZRelationshipToZoneClosure) -> ZoneArray? {
		var results: ZoneArray?
		for relationship in self {
			if  let item     = closure(relationship) {
				if  results == nil {
					results  = ZoneArray()
				}

				results?.append(item)
			}
		}

		return results
	}

	@discardableResult mutating func appendUniqueRelationship(_ relationship: ZRelationship?) -> Bool {
		if  let r = relationship {
			return appendUnique(item: r) { (a, b) -> (Bool) in
				if  let    ar  = (a as? ZRelationship),
					let    br  = (b as? ZRelationship) {
					return ar.from == br.from && ar.to == br.to    // is not unique, continue enumerating
				}

				return false        // is unique, add it and break out of enumerating
			}
		}

		return false
	}

}
