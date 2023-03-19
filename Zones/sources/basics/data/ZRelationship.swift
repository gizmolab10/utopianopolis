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

	@NSManaged public var          type : String?
	@NSManaged public var          from : String?
	@NSManaged public var            to : String?
	var                         _origin : ZRecord?
	var                       _relative : ZRecord?
	var                          origin : ZRecord?                    { if   _origin == nil {   _origin = from?.maybeZRecord }; return _origin }
	var                        relative : ZRecord?                    { if _relative == nil { _relative =   to?.maybeZRecord }; return _relative }
	var                           child : Zone?                       { return   origin as? Zone }
	var                          target : Zone?                       { return   origin as? Zone }
	var                          parent : Zone?                       { return relative as? Zone }
	var                        bookmark : Zone?                       { return relative as? Zone }
	var                        isParent : Bool                        { return type == ZRelationType.parent  .rawValue }
	var                      isBookmark : Bool                        { return type == ZRelationType.bookmark.rawValue }
	static func object(for id: String, isExpanded: Bool) -> NSObject? { return nil }
	func        object(for id: String, isExpanded: Bool) -> NSObject? { return nil }
	func        identifier()                             -> String?   { return description }

	static func uniqueRelationship(in databaseID: ZDatabaseID) -> ZRelationship? {
		var relationship: ZRelationship?

		gInvokeUsingDatabaseID(databaseID) {
			relationship = uniqueZRecord(entityName: kRelationshipType, recordName: nil, in: databaseID) as? ZRelationship
		}

		return relationship
	}

	var relationType : ZRelationType? {
		get { return type == nil ? nil : ZRelationType(rawValue: type!) }
		set { type = newValue?.rawValue }
	}

	override var description: String {
		switch relationType {
			case .bookmark: return "\(bookmark?.zoneName ?? kEmpty) (B) -> \(target?.zoneName ?? kEmpty)"
			case .parent:   return "\(parent?  .zoneName ?? kEmpty) (P) -> \(child? .zoneName ?? kEmpty)"
			case .none:     return kEmpty
		}
	}

}

enum ZRelationType: String {
	case bookmark = "b"
	case parent   = "p"

	var description: String {
		switch self {
			case .bookmark: return "Bookmark"
			case .parent:   return "Parent"
		}
	}
}
