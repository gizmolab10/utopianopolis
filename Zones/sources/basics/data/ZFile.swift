//
//  ZFile.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/24/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

struct ZFileDescriptor {
	let name: String?
	let type: String?
	let dbID: ZDatabaseID?
}

@objc(ZFile)
class ZFile : ZRecord {

	@NSManaged var                asset :  Data?
	@NSManaged var                 name :  String?
	@NSManaged var                 type :  String?
	override var        cloudProperties : StringsArray { return Zone.cloudProperties }
	override var optionalCloudProperties: StringsArray { return Zone.optionalCloudProperties }

	static func uniqueFile(recordName: String?, in dbID: ZDatabaseID) -> ZFile {
		return uniqueZRecord(entityName: kFileType, recordName: recordName, in: dbID) as! ZFile
	}

	static func assetExists(for descriptor: ZFileDescriptor, dbID: ZDatabaseID, onCompletion: ZRecordClosure? = nil) {
		gFilesRegistry.assetExists(for: descriptor) { iZRecord in
			if  iZRecord != nil {
				onCompletion?(iZRecord)
			} else {
				gCoreDataStack.fileExistsAsync(for: descriptor, dbID: dbID) { iZRecord in
					onCompletion?(iZRecord)
				}
			}
		}
	}

	static func uniqueFile(_ asset: CKAsset, databaseID: ZDatabaseID) {
		let  url = asset.fileURL
		let name = url.deletingPathExtension().lastPathComponent
		let type = url.pathExtension
		let desc = ZFileDescriptor(name: name, type: type, dbID: databaseID)

		assetExists(for: desc, dbID: databaseID) { iZRecord in
			if  iZRecord == nil {
				let   file = ZFile.uniqueFile(recordName: nil, in: databaseID)
				file .name = name
				file .type = type
				file.asset = url.dataRepresentation

				gFilesRegistry.register(file, in: databaseID)
			}
		}
	}

	// MARK:- properties
	// MARK:-

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
