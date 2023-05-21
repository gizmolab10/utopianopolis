//
//  ZDatabaseID.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/25/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation
import CloudKit

let kAllActualDatabaseIDs: ZDatabaseIDArray = [.mineID, .everyoneID]

enum ZDatabaseID: String {

	case  favoritesID = "favorites"
	case   everyoneID = "everyone"
	case     sharedID = "shared"
	case       mineID = "mine"

	var    identifier : String { return rawValue.substring(toExclusive: 1) } // { f, e, s, m }
	var    randomZone :   Zone { return Zone.uniqueZoneNamed(String(arc4random()), databaseID: self) }
	var isFavoritesDB :   Bool { return self == .favoritesID }
	var      hasStore :   Bool { return gCoreDataStack.hasStore(for: self) }
	var         index :   Int? { return databaseIndex?.rawValue }

	var zRecords: ZRecords? {
		switch self {
			case .favoritesID: return gFavoritesCloud
			case  .everyoneID: return  gEveryoneCloud
			case    .sharedID: return    gSharedCloud
			case      .mineID: return      gMineCloud
		}
	}

	var mapControlString: String {
		switch self {
			case .everyoneID: return "Mine"
			case   .sharedID: return "Shared"
			case     .mineID: return "Public"
			default:          return kEmpty
		}
	}

	var userReadableString: String {
		switch self {
			case .everyoneID: return "public"
			case   .sharedID: return "shared"
			case     .mineID: return "my"
			default:          return kEmpty
		}
	}

	var databaseIndex: ZDatabaseIndex? {
		switch self {
			case .favoritesID: return .favoritesIndex
			case  .everyoneID: return .everyoneIndex
			case    .sharedID: return .sharedIndex
			case      .mineID: return .mineIndex
		}
	}

	var scope: ZCDStoreType {
		switch self {
			case .everyoneID: return .sPublic
			case   .sharedID: return .sShared
			default:          return .sPrivate
		}
	}

	var acceptableMigrationIndex: Int {
		if  let a = index,
			let b = ZDatabaseID.mineID.index {
			return min(a, b)
		}

		return 0
	}

	func isDeleted(dict: ZStorageDictionary) -> Bool {
		let    name = dict[.recordName] as? String

		return name == nil ? false : zRecords?.manifest?.deletedRecordNames?.contains(name!) ?? false
	}

	// MARK: - ZFiles
	// MARK: -

	func uniqueFile(recordName: String?) -> ZFile {
		return ZRecord.uniqueZRecord(entityName: kFileType, recordName: recordName, in: self) as! ZFile
	}

	func assetExists(for descriptor: ZFileDescriptor) -> ZFile? {
		return gFilesRegistry.assetExists(for: descriptor) ?? gCoreDataStack.loadFile(for: descriptor)
	}

	func uniqueFile(_ asset: CKAsset) -> ZFile? {
		let  url  = asset.fileURL!
		do {
			let data  = try Data(contentsOf: url)
			let name  = url.deletingPathExtension().lastPathComponent
			let type  = url.pathExtension
			let desc  = ZFileDescriptor(name: name, type: type, databaseID: self)
			var file  = assetExists(for: desc)
			if  file == nil {
				file  = uniqueFile(recordName: nil)
				file! .name = name
				file! .type = type
				file!.asset = data
				file!.modificationDate = Date()

				gFilesRegistry.register(file!, in: self)
			}

			return file!
		} catch {
			printDebug(.dError, "\(error)")
		}

		return nil
	}

}

enum ZDatabaseIndex: Int { // N.B. do not change the order, these integer values are persisted everywhere
	case everyoneIndex
	case mineIndex
	case favoritesIndex
	case sharedIndex

	var databaseID: ZDatabaseID? {
		switch self {
			case .favoritesIndex: return .favoritesID
			case .everyoneIndex:  return .everyoneID
			case .sharedIndex:    return .sharedID
			case .mineIndex:      return .mineID
		}
	}
}

extension String {

	var databaseID: ZDatabaseID {
		switch self {
			case "f": return .favoritesID
			case "e": return .everyoneID
			case "s": return .sharedID
			case "m": return .mineID
			default:  return  gDatabaseID
		}
	}

}
