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

	var hasEmptyDatabase: Bool {
		if  let         parts  = components {
			let    databaseID  = parts[0]
			return databaseID == kEmpty
		}

		return false
	}

}
