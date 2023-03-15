//
//  ZRelationship.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/15/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

enum ZRelationshipType: String {
	case parent = "p"
}

@objc (ZRelationship)
class ZRelationship: ZRecord, ZIdentifiable {

	@NSManaged public var type: String?
	@NSManaged public var from: Zone?
	@NSManaged public var to: Zone?

	func identifier() -> String? {
		return nil
	}

	static func object(for id: String, isExpanded: Bool) -> NSObject? {
		return nil
	}
	
}
