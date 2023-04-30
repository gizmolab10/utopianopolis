//
//  ZDatabaseID.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/25/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

let kAllActualDatabaseIDs: ZDatabaseIDArray = [.mineID, .everyoneID]

enum ZDatabaseID: String {

	case  favoritesID = "favorites"
	case   everyoneID = "everyone"
	case     sharedID = "shared"
	case       mineID = "mine"

	var isFavoritesDB :   Bool { return self == .favoritesID }
	var      hasStore :   Bool { return gCoreDataStack.hasStore(for: self) }
	var    identifier : String { return rawValue.substring(toExclusive: 1) } // { f, e, s, m }
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

		return name == nil ? false : gRemoteStorage.zRecords(for: self)?.manifest?.deletedRecordNames?.contains(name!) ?? false
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
