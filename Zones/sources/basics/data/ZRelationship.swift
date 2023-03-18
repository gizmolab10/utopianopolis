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
	var                     _origin : ZRecord?
	var                   _relative : ZRecord?
	var                      origin : ZRecord? { if   _origin == nil {   _origin = from?.maybeZRecord }; return _origin }
	var                    relative : ZRecord? { if _relative == nil { _relative =   to?.maybeZRecord }; return _relative }
	var                       child : Zone?    { return   origin as? Zone }
	var                      parent : Zone?    { return relative as? Zone }

	static func uniqueRelationship(in databaseID: ZDatabaseID) -> ZRelationship? {
		var relationship: ZRelationship?

		gInvokeUsingDatabaseID(databaseID) {
			relationship = uniqueZRecord(entityName: kRelationshipType, recordName: nil, in: databaseID) as? ZRelationship
		}

		return relationship
	}

	func identifier() -> String? { return "\(parent?.zoneName ?? kEmpty) \(direction ?? kEmpty) \(child?.zoneName ?? kEmpty)" }

	func object(for id: String, isExpanded: Bool) -> NSObject? {
		if  let    relation = ZRelationType(rawValue: id) {
			switch relation {
				case .direction: return direction?.description as? NSString
				case .relative:  return relative
				case .plain:     return origin
			}
		}

		return nil
	}

	static func object(for id: String, isExpanded: Bool) -> NSObject? {    // gosh, lookup must examine both origin and relative
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
	case relative  = "r"
	case plain     = "p"

	var description: String {
		switch self {
			case .direction: return "Direction"
			case .plain:     return "Plain"
			case .relative:  return "Relative"
		}
	}
}
