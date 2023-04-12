//
//  ZMigration.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/10/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

var  gCDMigrationState    =                  ZCDMigrationState.mFirstTime
var  gCDMigrationIsDone   :   Bool { return  gCDMigrationState.isCompleted }
var  gCDBaseDataURL       :    URL { return  gFilesURL.appendingPathComponent(gDataDirectoryName) }
var  gDataDirectoryName   : String { return (gNormalDataLocation ? gNormalDirectoryName : "migration.testing") }
var  gNormalDirectoryName : String { return  kDataDirectoryName }
func gUpdateCDMigrationState()     {         gCDMigrationState = ZCDMigrationState.currentState }

enum ZCDMigrationState: Int {

	// //////////////////////////////////////////// //
	// 1. read files into CD                        //
	// 2. migrate original CD data into CK folders: //
	//        data/test2/cloud.public.store         //
	// 3. store to and retrieve from cloud          //
	// //////////////////////////////////////////// //

	case mFirstTime = 0
	case mFiles
	case mCDOriginal    // where currently submitted app stores it
	case mCDRelocated   // where app currently stores it (eg data/test2/cloud.public.store)
	case mUserID        // moved from "test2" to user's record id
	case mCloud

	var isActive : Bool {
		switch self {
			case .mFirstTime, .mFiles: return false
			default:                     return true
		}
	}

	var isCompleted : Bool {
		if  gUseLastSubmission {
			return self == .mCDRelocated
		} else if gCloudKit {
			return self == .mCloud
		} else {
			return self == .mCDOriginal
		}
	}

	static var currentState: ZCDMigrationState {

		let  everyoneID = ZDatabaseID.everyoneID
		let publicScope = everyoneID.scope

		// ////////////////////////////////////////////////////////// //
		//                                                            //
		//  mFirstTime   : mine file, store data, user ID don't exist //
		//  mFiles       : mine file exists but store data does not   //
		//  mCDOriginal  : data/cloud.public.store exists             //
		//  mCDRelocated : data/test2/cloud.public.store exists       //
		//  mCloud       : cloud data can be retrieved                //
		//                                                            //
		// ////////////////////////////////////////////////////////// //

		if  gCDBaseDataURL.fileExists {                 // data folder exists
			if  publicScope .ckStoreURL.containsData,   // data/test2/cloud.public.store.wal exists and is not empty
				everyoneID.hasStore {
				return                 .mCDRelocated
			}

			if  publicScope.originalURL.containsData,   // data/cloud.public.store exists
				everyoneID.hasStore {
				return                 .mCDOriginal
			}
		}

		if  gFiles.hasMine {
			return                     .mFiles
		}

		return                         .mFirstTime
	}

}

enum ZCKRepositoryID: String {
	case rOriginal  = "Zones"    // Thoughtful and early Seriously
	case rSubmitted = "test2"    // latest submitted to the app store
	case rUserID    = "dynamically uses user record name. if you can read this something is wrong"  // not yet submitted

	static var defaultIDs : [ZCKRepositoryID] { return [.rSubmitted, .rUserID] }
	static var        all : [ZCKRepositoryID] { return [.rOriginal, .rSubmitted, .rUserID] } // used for erasing CD stores
	var        cloudKitID : String            { return kBaseCloudID + kPeriod + rawValue }
	var    repositoryName : String?           { return (self == .rUserID) ? gUserRecordName : rawValue }
	var     repositoryURL : URL               { return gCDBaseDataURL.appendingPathComponent(repositoryName ?? kDefaultCDStore) }
	var  repositoryExists : Bool              { return repositoryURL.fileExists }
	func    removeFolder()                    {  try?  repositoryURL.remove() }

}

extension ZBatches {

	func load(into databaseID: ZDatabaseID, onCompletion: AnyClosure?) throws {
		gUpdateCDMigrationState()

		let finish: AnyClosure = { item in
			gUpdateCDMigrationState()
			onCompletion?(item)
		}

		switch gCDMigrationState {
			case .mFirstTime,
				 .mFiles: try gFiles.migrate(into: databaseID, onCompletion: finish)
			default:            gLoadContext(into: databaseID, onCompletion: finish)
		}
	}

}

extension ZCoreDataStack {

	func assureMigrationToLatest() {
		if !getRepositoryID() {
			gUpdateCDMigrationState()

			if  gCDMigrationState == .mCDOriginal {
				migrateFromCDOriginal()
				gUpdateCDMigrationState()
			}
		}

		persistentContainer = getPersistentContainer()

		if  gCloudKit, !gCDMigrationState.isActive {
			do {
				try persistentContainer?.initializeCloudKitSchema()
			} catch {
				printDebug(.dError, "\(error)")
			}
		}
	}

	func getRepositoryID() -> Bool {
		for id in ZCKRepositoryID.all.reversed() {
			if  id.repositoryExists {

				// ////////////////////////////////////////////////////////// //
				//                                                            //
				//  id.repositoryExists : repository file exists for this id  //
				//  gUseExistingStores  : don't erase the repository          //
				//  gUseLastSubmission  : use data/test2/cloud.public.store   //
				//  rUserID             : not yet submitted                   //
				//                                                            //
				// ////////////////////////////////////////////////////////// //

				if  gUseExistingStores, (gUseLastSubmission == (id != .rUserID)) {
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
			printDebug(.dError, "\(error)")
		}
	}

}

extension ZFiles {

	func migrate(into databaseID: ZDatabaseID, onCompletion: AnyClosure?) throws {
		if  !hasMine, databaseID == .mineID {
			onCompletion?(0)                   // mine file does not exist, do nothing (everyone file always exists)
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
			case .mFirstTime: return fileSizeFor(.everyoneID)
			case .mFiles:   return totalFilesSize
			default:          return 0
		}
	}

}

extension ZRemoteStorage {

	var totalLoadableRecordsCount: Int {
		switch gCDMigrationState {
			case .mFirstTime,
				 .mFiles: return gFiles.migrationFilesSize() / kFileRecordSize
			default:        return totalManifestCount
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
			} else if let parent  = parentZoneWrapper {
				setParentZone(parent)

				parentZoneMaybe   = parent
			}
		}

		return parentZoneMaybe
	}

	func setParentZone(_ parent: Zone?) {
		if  parentZoneMaybe  != parent {
			let priorParent   = parentZoneMaybe
			parentZoneWrapper = parent

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

	var parentZoneWrapper: Zone? {
		get {
			if  parentZoneMaybe    == nil {
				if  root           == self {
					unlinkParentAndMaybeNeedSave()
				} else if let  zone = parentLink?.maybeZone {
					parentZoneMaybe = zone
				} else if let parentRecordName = parentRID, parentRecordName != recordName { // noop (remain nil) when parentRID is nil or equals record name
					parentZoneMaybe = parentRecordName.maybeZone(in: databaseID)
				}
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
