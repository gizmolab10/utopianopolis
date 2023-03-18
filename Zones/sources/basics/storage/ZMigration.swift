//
//  ZMigration.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/10/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

extension ZCoreDataStack {

	// ///////////////////////////////////////////// //
	// migrating (CD & CK) data between repositories //
	// ///////////////////////////////////////////// //

	func assureMigrationToLatest() {
		migrateLocalCDRepository()

		persistentContainer = getPersistentContainer(cloudID: gCloudRepositoryID, at: ZCDStoreLocation.current.lastPathComponent)
		gCDMigrationState   = gCoreDataStack.hasStore() ? .normal : gFiles.hasMine ? .fromFilesystem : .firstTime

		if  gIsUsingCloudKit, !gIsCDMigrationDone {
			do {
				try persistentContainer?.initializeCloudKitSchema()
			} catch {
				print(error)
			}
		}
	}

	func migrateLocalCDRepository() {
		for id in ZCloudRepositoryID.all.reversed() {
			if  id.fileExists {
				gCloudRepositoryID = id

				return
			}
		}

		do {
			let location = ZCDStoreLocation.current.basePathComponent

			try gFileManager.moveSubpath(from: location, to: gCloudRepositoryID.rawValue, relativeTo: gFilesURL.path)
			try gFileManager.createDirectory(atPath: gFilesURL.appendingPathComponent(location).path, withIntermediateDirectories: true)
			try gFileManager.moveSubpath(from: gCloudRepositoryID.rawValue, to: location + kSlash + gCloudRepositoryID.rawValue, relativeTo: gFilesURL.path)
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
			case .firstTime:      return fileSizeFor(.everyoneID)
			case .fromFilesystem: return totalFilesSize
			default:              return 0
		}
	}

}

extension Zone {

	func getParentZone() -> Zone? {
		if !isARoot,
			parentZoneMaybe      == nil {
			if  let relationships = gRelationships.relationshipsFor(self),
				let relationship  = relationships.first {

				parentZoneMaybe   = relationship.parent
			} else if let parent  = oldParentZone {
				setParentZone(parent)

				parentZoneMaybe   = parent
			}
		}

		return parentZoneMaybe
	}

	func setParentZone(_ parent: Zone?) {
		if  parentZoneMaybe != parent {
			let priorParent  = parentZoneMaybe
			oldParentZone    = parent

			gRelationships.addOrSwapRelationship(self, parent: parent, priorParent: priorParent, in: databaseID)
		}
	}

	func migrateIntoRelationshipsEntity() {

	}

	func unlinkParentAndMaybeNeedSave() {
		if  parentZoneMaybe != nil ||
				(parentLink != nil &&
				 parentLink != kNullLink) {   // what about parentRID?
			parentZoneMaybe  = nil
			parentLink       = kNullLink
		}
	}

	var resolveParent: Zone? {
		let         old = parentZoneMaybe
		parentZoneMaybe = nil
		let         new = parentZone // recalculate _parentZone

		old?.removeChild(self)
		new?.addChildAndRespectOrder(self)

		return new
	}

	var oldParentZone: Zone? {
		get {
			if  root == self {
				unlinkParentAndMaybeNeedSave()
			} else if let  zone = parentLink?.maybeZone {
				parentZoneMaybe = zone
			} else if let parentRecordName = parentRID,
					  recordName != parentRecordName { // noop (remain nil) when parentRID equals record name
				parentZoneMaybe   = zRecords?.maybeZoneForRecordName(parentRecordName)
			}

			return parentZoneMaybe
		}

		set {
			if  root == self {
				unlinkParentAndMaybeNeedSave()
			} else if parentZoneMaybe    != newValue {
				parentZoneMaybe           = newValue
				if  parentZoneMaybe      == nil {
					unlinkParentAndMaybeNeedSave()
				} else if let parentName  = parentZoneMaybe?.recordName,
						  let parentDBID  = parentZoneMaybe?.databaseID {
					if        parentDBID == databaseID {
						if  parentRID    != parentName {
							parentRID     = parentName
							parentLink    = kNullLink
						}
					} else {                                                                                // new parent is in different db
						let newParentLink = parentDBID.rawValue + kColonSeparator + kColonSeparator + parentName

						if  parentLink   != newParentLink {
							parentLink    = newParentLink  // references don't work across dbs
							parentRID     = kNullParent
						}
					}
				}
			}
		}
	}

}

var gCloudRepositoryID: ZCloudRepositoryID {
	get {
		return gCloudRepositoryIDs[gCDLocationIsNormal ? 0 : 1]
	}
	set {
		var                          ids = gCloudRepositoryIDs
		ids[gCDLocationIsNormal ? 0 : 1] = newValue
		gCloudRepositoryIDs              = ids
	}
}

enum ZCDMigrationState: Int {
	case firstTime
	case fromFilesystem
	case toRelationships
	case toCloud
	case normal
}

enum ZCloudRepositoryID: String {
	case original = "Zones"
	case testing  = "test2"
	case latest   = "coredata"

	static var defaultIDs : [ZCloudRepositoryID] { return [.testing, .latest] }
	static var        all : [ZCloudRepositoryID] { return [.original, .testing, .latest] }
	var           cloudID : String       { return kBaseCloudID + kPeriod + rawValue }
	var lastPathComponent : String       { return ZCDStoreLocation.current.rawValue + kDataDirectoryName + kSlash + rawValue }
	var        fileExists : Bool         { return gFilesURL.appendingPathComponent(lastPathComponent).fileExists }

}

enum ZCDStoreLocation: String {
	case normal  = ""
	case migrate = "migration.testing."

	static var    current : ZCDStoreLocation { return gCDLocationIsNormal ? .normal : .migrate }
	var basePathComponent :           String { return rawValue + kDataDirectoryName }
	var lastPathComponent :           String { return "\(basePathComponent)/\(gCloudRepositoryID.rawValue)" }
}
