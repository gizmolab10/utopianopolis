//
//  ZMigration.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/10/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

enum ZCDMigrationState: Int {
	case firstTime
	case migrateFileData
	case normal
}

enum ZCDCloudID: Int {
	case original
	case testing
	case current

	static var all : [ZCDCloudID] { return [.original, .testing, .current] }
	var cloudID    : String       { return "\(kBaseCloudID).\(lastPathComponent)" }

	var lastPathComponent: String {
		switch self {
			case .original: return "Zones"
			case .testing:  return "test2"
			case .current:  return "coredata"
		}
	}

}

extension ZCoreDataMode {

	// MARK: - migrating data between persistent containers
	// MARK: -

	func migrateToLatest() {
		for type in ZCDStoreType.all {
			let id = detectCurrentCloudID(for: type)

			print("\(id) \(type.rawValue)")
		}
	}

	func detectCurrentCloudID(for type: ZCDStoreType) -> ZCDCloudID {
		for id in ZCDCloudID.all {
			if  containerExistsFor(id, type: type) {
				return id
			}
		}

		return gCDCloudID
	}

	func containerExistsFor(_ id: ZCDCloudID, type: ZCDStoreType) -> Bool {
		let cloudID = id.cloudID
		return false
	}

}

extension ZBatches {

	func load(into databaseID: ZDatabaseID, onCompletion: AnyClosure?) throws {
		switch gCDMigrationState {
			case .normal:  gLoadContext(into: databaseID, onCompletion: onCompletion)
			default: try gFiles.migrate(into: databaseID, onCompletion: onCompletion)
		}
	}

}

extension ZFiles {

	func migrate(into databaseID: ZDatabaseID, onCompletion: AnyClosure?) throws {
		if  !hasMine, databaseID == .mineID {
			onCompletion?(0)                   // mine file does not exist, do nothing
		} else {
			try readFile(into: databaseID) { [self] (iResult: Any?) in
				setupFirstTime()

				onCompletion?(iResult)
			}
		}
	}

	func migrationFilesSize() -> Int {
		switch gCDMigrationState {
			case .firstTime:       return fileSizeFor(.everyoneID)
			case .migrateFileData: return totalFilesSize
			default:               return 0
		}
	}

}
