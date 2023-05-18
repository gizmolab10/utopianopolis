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
	var                       _fromLink : ZoneLink?                   // internal var for capturing the from link and zone once (first time read)
	var                         _toLink : ZoneLink?                   // ditto                           to
	var                        fromLink : ZoneLink?                   { if _fromLink == nil { _fromLink = ZoneLink(link: from) }; return _fromLink }
	var                          toLink : ZoneLink?                   { if   _toLink == nil {   _toLink = ZoneLink(link:   to) }; return   _toLink }
	var                        fromZone : Zone?                       { return fromLink?.zone }
	var                          toZone : Zone?                       { return   toLink?.zone }
	var                           child : Zone?                       { return fromZone }
	var                          target : Zone?                       { return fromZone }
	var                          parent : Zone?                       { return   toZone }
	var                        bookmark : Zone?                       { return   toZone }
	static func object(for id: String, isExpanded: Bool) -> NSObject? { return nil } // not needed
	func        object(for id: String, isExpanded: Bool) -> NSObject? { return nil } // not needed
	func        identifier()                             -> String?   { return description }

	var opposite: ZRelationship? {
		if  let databaseID = to?.maybeDatabaseID {
			let     result = ZRelationship.uniqueRelationship(in: databaseID)
			result?  .type = relationType?.opposite.rawValue
			result?  .from = to
			result?    .to = from

			return result
		}

		return nil
	}

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
		let indicator = relationType?.rawValue.uppercased() ?? kQuestion

		return (fromZone?.zoneName ?? kQuestion) + " (" + indicator + ") -> " + (toZone?.zoneName ?? kQuestion)
	}

}

enum ZRelationType: String {
	case bookmark = "b"
	case parent   = "p"
	case child    = "c"
	case target   = "t"

	var description: String {
		switch self {
			case .bookmark: return "Bookmark"
			case .parent:   return "Parent"
			case .target:   return "Target"
			case .child:    return "Child"
		}
	}

	var opposite: ZRelationType {
		switch self {
			case .parent:   return .child
			case .child:    return .parent
			case .bookmark: return .target
			case .target:   return .bookmark
		}
	}
}
