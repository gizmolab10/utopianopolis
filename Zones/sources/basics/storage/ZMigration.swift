//
//  ZMigration.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/10/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

var  gCDMigrationState  =                  ZCDMigrationState.firstTime
var  gCDMigrationIsDone :   Bool { return  gCDMigrationState.isCompleted }
var  gCDBaseDataURL     :    URL { return  gFilesURL.appendingPathComponent(gDataDirectoryName) }
var  gDataDirectoryName : String { return (gNormalDataLocation ? kDataDirectoryName : "migration.testing") }
func gUpdateCDMigrationState()   {         gCDMigrationState = ZCDMigrationState.currentState }

enum ZCDMigrationState: Int {

	// //////////////////////////////////////////// //
	// 1. read files into CD                        //
	// 2. migrate original CD data into CK folders: //
	//        data/test2/cloud.public.store         //
	// 3. store to and retrieve from cloud          //
	// //////////////////////////////////////////// //

	case firstTime = 0
	case inFiles
	case inCDOriginal    // where currently submitted app stores it
	case inCDCloudKit    // where app currently stores it (eg data/test2/public)
	case inCloud

	var isActive : Bool {
		switch self {
			case .firstTime, .inFiles: return false
			default: return true
		}
	}

	var isCompleted : Bool {
		if  gCKUseLatest {
			return self == .inCDCloudKit
		} else if gIsUsingCloudKit {
			return self == .inCloud
		} else {
			return self == .inCDOriginal
		}
	}

	static var currentState: ZCDMigrationState {

		let  everyoneID = ZDatabaseID.everyoneID
		let publicScope = everyoneID.scope

		// ///////////////////////////////////////////////////////// //
		//                                                           //
		//  firstTime    : neither mine file nor store data exist    //
		//  inFiles      : mine file exists but store data does not  //
		//  inCDOriginal : data/cloud.public.store exists            //
		//  inCDCloudKit : data/test2/cloud.public.store exists      //
		//  inCloud      : cloud data can be retrieved               //
		//                                                           //
		// ///////////////////////////////////////////////////////// //

		if  gCDBaseDataURL.fileExists {                              // data folder exists
			if  publicScope .ckStoreURL.containsData,                // data/test2/cloud.public.store.wal exists and is not empty
				everyoneID.hasStore {
				return                 .inCDCloudKit
			}

			if  publicScope.originalURL.containsData,                // data/cloud.public.store exists
				everyoneID.hasStore {
				return                 .inCDOriginal
			}
		}

		if  gFiles.hasMine {
			return                     .inFiles
		}

		return                         .firstTime
	}

}

enum ZCKRepositoryID: String {
	case original  = "Zones"
	case submitted = "test2"
	case latest    = "CoreData"

	static var defaultIDs : [ZCKRepositoryID] { return [.submitted, .latest] }
	static var        all : [ZCKRepositoryID] { return [.original, .submitted, .latest] } // used for erasing CD stores
	var           baseURL : URL               { return gCDBaseDataURL.appendingPathComponent(rawValue) }
	var        cloudKitID : String            { return kBaseCloudID + kPeriod + rawValue }
	var        baseExists : Bool              { return baseURL.fileExists }
	func    removeFolder()                    {  try?  baseURL.remove() }

}

extension ZBatches {

	func load(into databaseID: ZDatabaseID, onCompletion: AnyClosure?) throws {
		gUpdateCDMigrationState()

		let finish: AnyClosure = { item in
			gUpdateCDMigrationState()
			onCompletion?(item)
		}

		switch gCDMigrationState {
			case .firstTime,
				 .inFiles: try gFiles.migrate(into: databaseID, onCompletion: finish)
			default:       gLoadContext      (into: databaseID, onCompletion: finish)
		}
	}

}

extension ZCoreDataStack {

	func assureMigrationToLatest() {
		if !getRepositoryID() {
			gUpdateCDMigrationState()

			if  gCDMigrationState == .inCDOriginal {
				migrateFromCDOriginal()
				gUpdateCDMigrationState()
			}
		}

		persistentContainer = getPersistentContainer()

		if  gIsUsingCloudKit, !gCDMigrationState.isActive {
			do {
				try persistentContainer?.initializeCloudKitSchema()
			} catch {
				print(error)
			}
		}
	}

	func getRepositoryID() -> Bool {
		for id in ZCKRepositoryID.all.reversed() {
			if  id.baseExists {
				if  gUseExistingStores, (!gCKUseLatest || id == .latest) {
					gCKRepositoryID = id

					return true
				}

				id.removeFolder()
			}
		}

		return false
	}

	func migrateFromCDOriginal() {
		do {
			let moveTemporary = "temp"
			let      moveFrom = gDataDirectoryName                            // data
			let        moveTo = moveFrom + kSlash + gCKRepositoryID.rawValue  // data/test2
			let         urlTo = gFilesURL.appendingPathComponent(moveTo).path
			let          path = gFilesURL.path
			let             m = gFileManager

			try m.moveSubpath(from: moveFrom,      to: moveTemporary, relativeTo: path)
			try m.createDirectory(atPath: urlTo, withIntermediateDirectories: true)
			try m.moveSubpath(from: moveTemporary, to: moveTo,        relativeTo: path)
		} catch {
			print("\(error)")
		}
	}

}

extension ZFiles {

	func migrate(into databaseID: ZDatabaseID, onCompletion: AnyClosure?) throws {
		if  !hasMine, databaseID == .mineID {
			onCompletion?(0)                   // mine file does not exist, do nothing
		} else {
			try readFile(into: databaseID) { result in
				gColorfulMode = true
				gStartupLevel = .localOkay
				gDatabaseID   = .everyoneID

				gSaveContext()
				gEveryoneCloud?.rootZone?.expandAndGrab(focus: false)

				onCompletion?(result)
			}
		}
	}

	func migrationFilesSize() -> Int {
		switch gCDMigrationState {
			case .firstTime: return fileSizeFor(.everyoneID)
			case .inFiles:   return totalFilesSize
			default:         return 0
		}
	}

}

extension ZRemoteStorage {

	var totalLoadableRecordsCount: Int {
		switch gCDMigrationState {
			case .inFiles: return gFiles.migrationFilesSize() / kFileRecordSize
			default:       return totalManifestCount
		}
	}

}

extension Zone {

	func getParentZone() -> Zone? {
		if !isARoot,
			parentZoneMaybe      == nil {
			if  let relationships = gRelationships.relationshipsFor(self),
				let parent        = relationships.parents?.first {

				parentZoneMaybe   = parent
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

			gRelationships.addOrSwapParentRelationship(self, parent: parent, priorParent: priorParent, in: databaseID)
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
			if  root             == self {
				unlinkParentAndMaybeNeedSave()
			} else if let  zone   = parentLink?.maybeZone {
				parentZoneMaybe   = zone
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
						let newParentLink = parentDBID.rawValue + kDoubleColonSeparator + parentName

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
