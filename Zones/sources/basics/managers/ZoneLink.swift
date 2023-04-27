//
//  ZRelationNode.swift
//  Seriously
//
//  Created by Jonathan Sand on 03/25/23.
//  Copyright © 2023 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

// computes a Zone from a link
// three components separated by a colon
// database identifier, <unknown>, record name

@objc (ZoneLink)
class ZoneLink : NSObject {
	var  link : String?
	var _zone : Zone?
	var  redo = false

	init(link iLink: String?) {
		super.init()
		link = iLink

		if  link?.hasEmptyDatabase ?? false {
			redo = true // redo means a wild card (one of the three components is empty), and must be recomputed each time
		}
	}

	var zone: Zone? {
		if  _zone == nil || redo {
			_zone  = link?.maybeZone
		}

		return _zone
	}
}

extension String {

	var  isValidLink :         Bool              { return components != nil }
	var  maybeZone   :         Zone?             { return maybeZRecord?.maybeZone }
	var  components  : StringsArray?             { return components(separatedBy: kColonSeparator) }
	func maybeZone(in id: ZDatabaseID?) -> Zone? { return maybeZRecord(in: id)?.maybeZone }

	var maybeZRecord: ZRecord? {
		if  self          != kEmpty,
			let       name = maybeRecordName,
			let databaseID = maybeDatabaseID {

			return name.maybeZRecord(in: databaseID)
		}

		return nil
	}

	var maybeRecordName: String? {
		if  let   parts  = components, parts.count > 1 {
			let    name  = parts[2]
			return name != kEmpty ? name : kRootName // by design: empty component means root
		}

		return nil
	}

	var maybeDatabaseID: ZDatabaseID? {
		if  let         parts  = components {
			let    databaseID  = parts[0]
			return databaseID == kEmpty ? gDatabaseID : ZDatabaseID(rawValue: databaseID)
		}

		return nil
	}

	var hasEmptyDatabase: Bool {
		if  let         parts  = components {
			let    databaseID  = parts[0]
			return databaseID == kEmpty
		}

		return false
	}

}
