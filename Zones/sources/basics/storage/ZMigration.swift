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

enum ZCDCloudID: String {
	case original = "Zones"
	case testing  = "test2"
	case latest   = "coredata"

	static var defaultIDs : [ZCDCloudID] { return [.testing, .latest] }
	static var        all : [ZCDCloudID] { return [.original, .testing, .latest] }
	var           cloudID : String       { return kBaseCloudID + kPeriod + rawValue }
	var lastPathComponent : String       { return ZCDStoreLocation.current.rawValue + kDataDirectoryName + kSlash + rawValue }
	var        fileExists : Bool         { return gFilesURL.appendingPathComponent(lastPathComponent).fileExists }

}

enum ZCDStoreLocation: String {
	case normal  = ""
	case migrate = "migration.testing."

	static var    current : ZCDStoreLocation { return gCDLocationIsNormal ? .normal : .migrate }
	var basePathComponent :           String { return rawValue + kDataDirectoryName }
	var lastPathComponent :           String { return "\(basePathComponent)/\(gCDCloudID.rawValue)" }
}

extension ZCoreDataStack {

	// //////////////////////////////////////////// //
	// migrating data between persistent containers //
	// //////////////////////////////////////////// //

	func migrateToLatest() {
		migrateDataDirectory()

		persistentContainer = getPersistentContainer(cloudID: gCDCloudID, at: ZCDStoreLocation.current.lastPathComponent)
		gCDMigrationState   = gCoreDataStack.hasStore() ? .normal : gFiles.hasMine ? .migrateFileData : .firstTime
	}

	func migrateDataDirectory() {
		for id in ZCDCloudID.all.reversed() {
			if  id.fileExists {
				gCDCloudID = id

				return
			}
		}

		do {
			let location = ZCDStoreLocation.current.basePathComponent

			try gFileManager.moveSubpath(from: location, to: gCDCloudID.rawValue, relativeTo: gFilesURL.path)
			try gFileManager.createDirectory(atPath: gFilesURL.appendingPathComponent(location).path, withIntermediateDirectories: true)
			try gFileManager.moveSubpath(from: gCDCloudID.rawValue, to: location + kSlash + gCDCloudID.rawValue, relativeTo: gFilesURL.path)
		} catch {
			print("\(error)")
		}
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
