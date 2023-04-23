//
//  ZSharingService.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/22/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class ZSharingService : NSSharingService {

	static func createService(named: Any) {
//		let service = ZSharingService()
		
	}

	func invokeShare() {}
}
