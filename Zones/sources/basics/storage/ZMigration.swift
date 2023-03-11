//
//  ZMigration.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/10/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

extension ZCoreDataMode {

	// MARK: - migrating data between ck containers
	// MARK: -

	func migrateToLatest() {
		let id = detectCurrentCloudID()

		print(id)
	}

	func detectCurrentCloudID() -> ZCDCloudID {
		for id in ZCDCloudID.all {
			if  containerExistsFor(id) {
				return id
			}
		}

		return gCDCloudID
	}

	func containerExistsFor(_ id: ZCDCloudID) -> Bool {
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
