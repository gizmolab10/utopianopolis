//
//  ZFile.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/24/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import CloudKit
import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

struct ZFileDescriptor {
	let name: String?
	let type: String?
	let dbID: ZDatabaseID?
}

@objc(ZFile)
class ZFile : ZRecord {

	@NSManaged var asset : Data?
	@NSManaged var  name : String?
	@NSManaged var  type : String?

	var filename : String? {
		if  let n = name, let t = type {
			return databaseID.identifier + kDotSeparator + n + kDotSeparator + t
		}

		return nil
	}

	func activate() { gFiles.unqiueAssetPath(for: self)?.openAsURL() }

	// MARK: - create
	// MARK: -

	static func uniqueFile(recordName: String?, in dbID: ZDatabaseID) -> ZFile {
		return uniqueZRecord(entityName: kFileType, recordName: recordName, in: dbID) as! ZFile
	}

	static func assetExists(for descriptor: ZFileDescriptor, dbID: ZDatabaseID) -> ZFile? {
		return gFilesRegistry.assetExists(for: descriptor) ?? gCoreDataStack.loadFile(for: descriptor)
	}

	static func uniqueFile(_ asset: CKAsset, databaseID: ZDatabaseID) -> ZFile? {
		let  url  = asset.fileURL
		do {
			let data  = try Data(contentsOf: url)
			let name  = url.deletingPathExtension().lastPathComponent
			let type  = url.pathExtension
			let desc  = ZFileDescriptor(name: name, type: type, dbID: databaseID)
			var file  = assetExists(for: desc, dbID: databaseID)
			if  file == nil {
				file  = ZFile.uniqueFile(recordName: nil, in: databaseID)
				file! .name = name
				file! .type = type
				file!.asset = data
				file!.modificationDate = Date()

				gFilesRegistry.register(file!, in: databaseID)
			}

			return file!
		} catch {
			print(error)
		}

		return nil
	}

	// MARK: - properties
	// MARK: -

	override var        cloudProperties : StringsArray { return Zone.cloudProperties }
	override var optionalCloudProperties: StringsArray { return Zone.optionalCloudProperties }

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
