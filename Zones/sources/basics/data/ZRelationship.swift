//
//  ZRelationship.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/15/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

@objc (ZRelationship)
class ZRelationship: ZRecord, ZIdentifiable {

	@NSManaged public var direction : String?
	@NSManaged public var      from : String?
	@NSManaged public var        to : String?
	var                      _owner : ZRecord?
	var                    _related : ZRecord?
	var                       owner : ZRecord? { if   _owner == nil {   _owner = from?.maybeZRecord }; return _owner }
	var                     related : ZRecord? { if _related == nil { _related =   to?.maybeZRecord }; return _related }
	var                        zone : Zone?    { return   owner as? Zone }
	var                      parent : Zone?    { return related as? Zone }

	@discardableResult static func addUniqueRelationship(_ zone: Zone, parent: Zone?, in databaseID: ZDatabaseID) -> ZRelationship? {
		if  let          from = zone   .asString,
			let            to = parent?.asString {
			let  relationship = ZRelationship.uniqueRelationship(in: databaseID) // this crashes
			relationship.from = from
			relationship  .to = to

			gRelationships.addRelationship(relationship)

			return relationship
		}

		return nil
	}

	static func uniqueRelationship(in databaseID: ZDatabaseID) -> ZRelationship {
		let  relationship = uniqueZRecord(entityName: kRelationshipType, recordName: nil, in: databaseID) as! ZRelationship   // this crashes

		return relationship
	}

	func identifier() -> String? { return "\(zone?.zoneName ?? kEmpty) \(direction ?? kEmpty) \(parent?.zoneName ?? kEmpty)" }

	func object(for id: String, isExpanded: Bool) -> NSObject? {
		if  let relation = ZRelationType(rawValue: id) {
			switch relation {
				case .direction: return direction?.description as? NSString
				case .related:   return related
				case .plain:     return owner
			}
		}

		return nil
	}

	static func object(for id: String, isExpanded: Bool) -> NSObject? {    // gosh, lookup must examine both owner and related
		return nil
	}

}

enum ZDirectionType: String {
	case parent        = "p"
	case bidirectional = "b"

	var description: String {
		switch self {
			case .parent:        return "Parent"
			case .bidirectional: return "Bidirectional"
		}
	}
}

enum ZRelationType: String {
	case direction = "d"
	case related   = "r"
	case plain     = "p"

	var description: String {
		switch self {
			case .direction: return "Direction"
			case .plain:     return "Plain"
			case .related:   return "Related"
		}
	}
}
