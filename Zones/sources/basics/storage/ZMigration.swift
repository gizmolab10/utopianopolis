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
var  gDataDirectoryName   : String { return (gNormalDataLocation ? kDataDirectoryName : "migration.testing") }
func gUpdateCDMigrationState()     {         gCDMigrationState = ZCDMigrationState.currentState }

enum ZCDMigrationState: Int {

	// //////////////////////////////////////////// //
	// 1. read files into CD                        //
	// 2. migrate original CD data into CK folders: //
	//        data/test2/cloud.public.store         //
	// 3. store to and retrieve from cloud          //
	// //////////////////////////////////////////// //

	case mFirstTime = 0
	case mFiles         // *.seriously
	case mCDOriginal    // data
	case mCDHierarchal  // data/test2
	case mUserID        // data/<user's record id>
	case mCloud         // data can be retrieved from the remote cloud

	var isActive : Bool { return ![.mFirstTime, .mFiles].contains(self) }

	var isCompleted : Bool {

		// //////////////////////////////////////////////////////// //
		//                                                          //
		//    determine whether or not migration is complete by     //
		//    matching feature              (first letter g)        //
		//    to appropriate final state    (first letter m)        //
		//    determined below by currentState                      //
		//                                                          //
		//  gUseUserID    : use data/<userID>/cloud.public.store    //
		//  mUserID       : data exists at data/<user's record id>  //
		//  gUseHierarchy : data/test2 instead of just data         //
		//  mCDHierarchal : data/test2/cloud.public.store exists    //
		//  gCloudKit     : actually store data in the cloud        //
		//  mCloud        : data can be retrieved from the cloud    //
		//  mCDOriginal   : data/cloud.public.store exists          //
		//                                                          //
		// //////////////////////////////////////////////////////// //

		if                    gUseUserID {
			return   self == .mUserID
		} else if             gUseHierarchy {
			return   self == .mCDHierarchal
		} else if             gUseCloud {
			return   self == .mCloud                // TODO: NEVER true
		} else {
			return   self == .mCDOriginal
		}
	}

	static var currentState: ZCDMigrationState {

		// /////////////////////////////////////////////////////////// //
		//                                                             //
		//  mFirstTime    : mine file, store data, user ID don't exist //
		//  mFiles        : mine file exists but store data does not   //
		//  mCDOriginal   : data/cloud.public.store exists             //
		//  mCDHierarchal : data/test2/cloud.public.store exists       //
		//  mCloud        : cloud data can be retrieved   ? ? ? ? ?    // see the TODO above
		//                                                             //
		// /////////////////////////////////////////////////////////// //

		let publicScope = ZDatabaseID.everyoneID.scope

		if  gCDBaseDataURL.fileExists {                 // data folder exists
			if  publicScope .ckStoreURL.containsData {  // data/test2/cloud.public.store exists and is not empty
				return                 .mCDHierarchal
			}

			if  publicScope.originalURL.containsData {  //       data/cloud.public.store exists and is not empty
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

			if  gCDMigrationState == .mCDOriginal,
				let        toName  = gCKRepositoryID.repositoryName {                 // toName path ends in either  test2  or  <user id>
				migrateFrom(gDataDirectoryName, gDataDirectoryName + kSlash + toName) // move from o;d flat data folder
				gUpdateCDMigrationState()
			}

			if	gCDMigrationState == .mCDHierarchal, !getRepositoryID(), gUseUserID,
				let      fromName  =  ZCKRepositoryID.rSubmitted.repositoryName,      // fromName ends in  test2
				let        toName  =  ZCKRepositoryID.rUserID   .repositoryName {     //   toName ends in  <user id>
				gCKRepositoryID    = .rUserID

				migrateFrom(gDataDirectoryName + kSlash + fromName, gDataDirectoryName + kSlash + toName)
				gUpdateCDMigrationState()
			}
		}
	}

	func assureContainerIsSetup() {
		if  persistentContainer == nil {
			persistentContainer  = getPersistentContainer()

			if  gUseCloud, !gCDMigrationState.isActive {
				do {
					try persistentContainer?.initializeCloudKitSchema()
				} catch {
					printDebug(.dError, "\(error)")
				}
			}

			gUpdateCDMigrationState()
		}
	}

	func getRepositoryID() -> Bool {
		for id in ZCKRepositoryID.all.reversed() {
			if  id.repositoryExists {

				// //////////////////////////////////////////////////////////// //
				//                                                              //
				//  id.repositoryExists : repository file exists for this id    //
				//  gUseExistingStores  : don't erase the repository            //
				//  gUseUserID          : use data/<userID>/cloud.public.store  //
				//  rUserID             : is using userID                       //
				//                                                              //
				// //////////////////////////////////////////////////////////// //

				if !gUseExistingStores {
					id.removeFolder()
				} else if gUseUserID == (id == .rUserID) {
					gCKRepositoryID = id

					return true
				}
			}
		}

		return false
	}

	func migrateFrom(_ moveFrom: String, _ moveTo: String) {
		do {
			let moveTemporary = "temp"
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
			gCoreDataStack.assureContainerIsSetup()
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
