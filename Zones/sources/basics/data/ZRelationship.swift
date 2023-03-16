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

	@NSManaged public var type : String?
	@NSManaged public var from : String?
	@NSManaged public var   to : String?
	var                 _owner : ZRecord?
	var               _related : ZRecord?
	var                  owner : ZRecord? { if   _owner == nil {   _owner = from?.maybeZRecord }; return _owner }
	var                related : ZRecord? { if _related == nil { _related =   to?.maybeZRecord }; return _related }

	func identifier() -> String? { return type?.description }

	func object(for id: String, isExpanded: Bool) -> NSObject? {
		if  let relation = ZRelationType(rawValue: id) {
			switch relation {
				case .type:    return type?.description as? NSString
				case .owner:   return owner
				case .related: return related
			}
		}

		return nil
	}

	static func object(for id: String, isExpanded: Bool) -> NSObject? {    // gosh, lookup must examine both owner and related
		return nil
	}

}

enum ZRelationshipType: String {
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
	case type    = "t"
	case owner   = "o"
	case related = "r"

	var description: String {
		switch self {
			case .type:    return "Type"
			case .owner:   return "Owner"
			case .related: return "Related"
		}
	}
}
