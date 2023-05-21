//
//  ZFile.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/24/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

struct ZFileDescriptor {
	let name: String?
	let type: String?
	let databaseID: ZDatabaseID?
}

@objc(ZFile)
class ZFile : ZRecord {

	@NSManaged var asset : Data?
	@NSManaged var  name : String?
	@NSManaged var  type : String?

	var filename : String? {
		if  let n = name, let t = type {
			return databaseID.identifier + kPeriod + n + kPeriod + t
		}

		return nil
	}

	func activate() { gFiles.unqiueAssetPath(for: self)?.openAsURL() }

	// MARK: - properties
	// MARK: -

	override var        cloudProperties : StringsArray { return ZFile.cloudProperties }
	override var optionalCloudProperties: StringsArray { return ZFile.optionalCloudProperties }

	override class var cloudProperties: StringsArray {
		return optionalCloudProperties +
			super.cloudProperties
	}

	override class var optionalCloudProperties: StringsArray {
		return [#keyPath(asset),
				#keyPath(name),
				#keyPath(type)] +
			super.optionalCloudProperties
	}

}
