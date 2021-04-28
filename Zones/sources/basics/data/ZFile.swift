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
	override var        cloudProperties : [String] { return Zone.cloudProperties }
	override var optionalCloudProperties: [String] { return Zone.optionalCloudProperties }

	static func create(record: CKRecord, databaseID: ZDatabaseID?) -> ZFile {
		if  let    has = hasMaybe(record: record, entityName: kFileType, databaseID: databaseID) as? ZFile {        // first check if already exists
			return has
		}

		return ZFile(record: record, databaseID: databaseID)
	}

	static func assetExists(for descriptor: ZFileDescriptor, onCompletion: ZRecordClosure? = nil) {
		gFilesRegistry.assetExists(for: descriptor) { iZRecord in
			if  iZRecord != nil {
				onCompletion?(iZRecord)
			} else {
				gCoreDataStack.assetExists(for: descriptor) { iZRecord in
					onCompletion?(iZRecord)
				}
			}
		}
	}

	static func createFrom(_ asset: CKAsset, databaseID: ZDatabaseID?) {
		let  url = asset.fileURL
		let name = url.deletingPathExtension().lastPathComponent
		let type = url.pathExtension
		let desc = ZFileDescriptor(name: name, type: type, dbID: databaseID)

		assetExists(for: desc) { iZRecord in
			if  iZRecord == nil {
				let   file = ZFile.create(record: CKRecord(recordType: kFileType), databaseID: databaseID)
				file .name = name
				file .type = type
				file.asset = url.dataRepresentation

				gFilesRegistry.register(file, in: databaseID)
			}
		}
	}

	// MARK:- properties
	// MARK:-

	override class var cloudProperties: [String] {
		return optionalCloudProperties +
			super.cloudProperties
	}

	override class var optionalCloudProperties: [String] {
		return [#keyPath(asset),
				#keyPath(name),
				#keyPath(type)] +
			super.optionalCloudProperties
	}

}
