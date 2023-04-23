//
//  ZMigration.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/10/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation
import CloudKit

var  gCDMigrationState    =                  ZCDMigrationState.mFirstTime
var  gCDMigrationIsDone   :   Bool { return  gCDMigrationState.isCompleted }
var  gCDBaseDataURL       :    URL { return  gFilesURL.appendingPathComponent(gDataDirectoryName) }
var  gDataDirectoryName   : String { return (gCDNormalStore ? kDataDirectoryName : "migration.testing") }
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
		//  gUseCloud     : actually store data in the cloud        //
		//  gUseUserID    : use data/<userID>/cloud.public.store    //
		//  gUseHierarchy : data/test2 instead of just data         //
		//                                                          //
		//  mCloud        : data can be retrieved from the cloud    //
		//  mUserID       : data exists at data/<user's record id>  //
		//  mCDHierarchal : data exists at data/test2               //
		//  mCDOriginal   : data exists at data                     //
		//                                                          //
		// //////////////////////////////////////////////////////// //

		if                    gCDUseCloud {
			return   self == .mCloud                // TODO: NEVER true
		} else if             gCDUseUserID {
			return   self == .mUserID
		} else if             gCDUseHierarchy {
			return   self == .mCDHierarchal
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

		// if user id is not known -> FUBAR (wrong migration location, data will be lost once user id becomes known)

		let publicScope = ZDatabaseID.everyoneID.scope

		if  gCDBaseDataURL.fileExists {                                   // data           <- folder exists
			if  let url = publicScope.ckUserIDURL,    url.containsData {  // data/<user id> <- store exists and is not empty
				return               .mUserID
			}

			if  let url = publicScope.ckSubmittedURL, url.containsData {  // data/test2     <- store exists and is not empty
				return               .mCDHierarchal
			}

			if  publicScope          .originalURL        .containsData {  // data           <- store exists and is not empty
				return               .mCDOriginal
			}
		}

		if  gFiles.hasMine {
			return                   .mFiles
		}

		return                       .mFirstTime
	}

}


enum ZCKRepositoryID: String {
	case rOriginal  = "Zones"    // Thoughtful and early Seriously
	case rSubmitted = "test2"    // latest submitted to the app store
	case rUserID    = "dynamically uses user record name. if you can read this something is wrong"  // not yet submitted

	static var defaultIDs : [ZCKRepositoryID] { return [.rSubmitted, .rUserID] }
	static var        all : [ZCKRepositoryID] { return [.rOriginal, .rSubmitted, .rUserID] } // used for erasing CD stores
	var        cloudKitID : String?           { return kBaseCloudID + kPeriod  + cloudKitName }
	var      cloudKitName : String            { return notUseUserID ? rawValue : storeName }
	var         storeName : String            { return gCDNormalStore ? kDefaultCDStore : kMigrationTestCDStore }
	var    repositoryName : String            { return notUseUserID ? rawValue : (gUserID ?? submittedName) }
	var     submittedName : String            { return ZCKRepositoryID.rSubmitted.rawValue }
	var     repositoryURL : URL?              { return gCDBaseDataURL.appendingPathComponent(repositoryName) }
	var  repositoryExists : Bool              { return repositoryURL?.fileExists ?? false }
	var      notUseUserID : Bool              { return self != .rUserID }
	func    removeFolder()                    {  try?  repositoryURL?.remove() }

	static func updateRepositoryID() {
		for id in all.reversed() {
			if  id.repositoryExists {

				// //////////////////////////////////////////////////////////// //
				//                                                              //
				//  id.repositoryExists : repository file exists for this id    //
				//  gUseExistingStores  : don't erase the repository            //
				//  gUseUserID          : use data/<userID>/cloud.public.store  //
				//  rUserID             : is using userID                       //
				//                                                              //
				// //////////////////////////////////////////////////////////// //

				if !gCDUseExistingStores {
					id.removeFolder()
				} else if gCDUseUserID == (id == .rUserID) {
					gCKRepositoryID = id

					return
				}
			}
		}

		gCKRepositoryID = (gCDUseUserID && gUserRecordName != nil) ? .rUserID : .rSubmitted
	}

}

extension ZBatches {

	func load(into databaseID: ZDatabaseID, onCompletion: AnyClosure?) throws {
		gUpdateCDMigrationState()

		let finish: AnyClosure = { loadResult in
			gUpdateCDMigrationState()
			onCompletion?(loadResult)
		}

		switch gCDMigrationState {
			case .mFirstTime,
				 .mFiles: try gFiles.migrate(into: databaseID, onCompletion: finish)
			default:            gLoadContext(into: databaseID, onCompletion: finish)
		}
	}

	func migrateFromCloud(into databaseID: ZDatabaseID, onCompletion: AnyClosure?) {
		if  databaseID == .mineID {
			gMineCloud?.loadEverythingMaybe { everythingResult in // because Seriously is now running on a second device
				onCompletion?(everythingResult)
			}
		} else {
			onCompletion?(0)
		}
	}

}

extension ZCoreDataStack {

	func updateForMigration() {
		ZCKRepositoryID.updateRepositoryID()
		gUpdateCDMigrationState()
	}

	func assureMigrationToLatest() {
		updateForMigration()

		if  gCDUseHierarchy {
			if  gCDMigrationState == .mCDOriginal,
				let            to  = gCKRepositoryID.repositoryName.dataExtensionPath {            //   to ends in either  test2  or  <user id>
				gDataDirectoryName.migrateTo(to)                                                   // move from old flat data folder
				updateForMigration()
			}

			if	gCDMigrationState == .mCDHierarchal, gCDUseUserID,
				let            to  =  gUserRecordName?.dataExtensionPath,                          //   to ends in  <user id>
				let          from  =  ZCKRepositoryID.rSubmitted.rawValue.dataExtensionPath {      // from ends in  test2

				from.migrateTo(to)  // move to new user id folder
				updateForMigration()
			}
		}
	}

	func assureContainerIsSetup() {
		if  persistentContainer == nil {
			persistentContainer  = getPersistentContainer()

			if  gCDUseCloud, !gCKIsInitialized {
				do {
					try persistentContainer?.initializeCloudKitSchema()
				} catch {
					printDebug(.dError, "\(error)")
				}
			}

			gUpdateCDMigrationState()
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
				gUpdateCDMigrationState()

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
					if        parentDBID != maybeDatabaseID {                                  // new parent is in different db
						let newParentLink = parentDBID.rawValue + kDoubleColonSeparator + parentName

						if  parentLink   != newParentLink {
							parentLink    = newParentLink  // references don't work across dbs
							parentRID     = kNullParent
						}
					} else if parentRID  != parentName {
						parentRID         = parentName
						parentLink        = kNullLink
					}
				}
			}
		}
	}

}

extension ZManifest {

	func extractData(from ckRecord: CKRecord) {
		count = ckRecord.value(forKeyPath: "CD_count") as? NSNumber

		// TODO: deletedZones ... or not, since we are using isTrashed instead
	}

}

extension ZTrait {

	func extractData(from ckRecord: CKRecord) {
		text      = ckRecord.value(forKeyPath: "CD_text")      as? String
		type      = ckRecord.value(forKeyPath: "CD_type")      as? String
		format    = ckRecord.value(forKeyPath: "CD_format")    as? String
		ownerLink = ckRecord.value(forKeyPath: "CD_ownerLink") as? String
		ownerRID  = ckRecord.value(forKeyPath: "CD_ownerRID")  as? String

		// TODO: strings and owner (they are transformables)
	}

}

extension Zone {

	func extractData(from ckRecord: CKRecord) {
		zoneName       = ckRecord.value(forKeyPath: "CD_zoneName")       as? String
		zoneLink       = ckRecord.value(forKeyPath: "CD_zoneLink")       as? String
		zoneColor      = ckRecord.value(forKeyPath: "CD_zoneColor")      as? String
		parentRID      = ckRecord.value(forKeyPath: "CD_parentRID")      as? String
		parentLink     = ckRecord.value(forKeyPath: "CD_parentLink")     as? String
		zoneAuthor     = ckRecord.value(forKeyPath: "CD_zoneAuthor")     as? String
		zoneAttributes = ckRecord.value(forKeyPath: "CD_zoneAttributes") as? String
		zoneProgeny    = ckRecord.value(forKeyPath: "CD_zoneProgeny")    as? NSNumber
		zoneAccess     = ckRecord.value(forKeyPath: "CD_zoneAccess")     as? NSNumber
	}

}

extension CKRecord {

	func createZRecord(of type: String, in databaseID: ZDatabaseID) -> ZRecord? {
		var zRecord: ZRecord?

		if  let                  name = value(forKeyPath: "CD_recordName")    as? String {
			zRecord                   = ZRecord.uniqueZRecord(entityName: type, recordName: name, in: databaseID)
			zRecord?            .dbid = value(forKeyPath: "CD_dbid")          as? String
			zRecord?.modificationDate = value(forKeyPath: "modificationDate") as? Date
			zRecord?       .isTrashed = value(forKeyPath: "CD_isTrashed")     as? NSNumber

			switch type {
				case        kZoneType: zRecord?.maybeZone?    .extractData(from: self)
				case    kManifestType: zRecord?.maybeManifest?.extractData(from: self)
				case kTraitAssetsType: zRecord?.maybeTrait?   .extractData(from: self)
				default:                break
			}
		}

		return zRecord
	}

}

extension ZCloud {

	func loadEverythingMaybe(onCompletion: AnyClosure?) {
		var typeCount = 3

		guard gCDUseCloud, gCDPreloadFromCK, (rootZone == nil || rootZone!.count == 0) else {
			onCompletion?(0)

			return
		}

		for type in [kZoneType, kTraitAssetsType, kManifestType] {
			fetchAllRecords(of: type) { [self] ckRecords in
				print("fetched \(ckRecords.count) \(type) record(s)")

				gShowAppIsBusyWhile { [self] in    // adding records must be done in FOREGROUND: to avoid corruption and mutation while enumerating
					for ckRecord in ckRecords {
						let zRecord = ckRecord.createZRecord(of: type, in: databaseID)

						zRecord?.register()
					}

					typeCount -= 1

					if  typeCount == 0 {
						assureAdoption { value in
							onCompletion?(0)
						}
					}
				}
			}
		}
	}


	func fetchAllRecords(of type: String, closure: CKRecordsClosure?) {
		var ckRecords = CKRecordsArray()
		let predicate = NSPredicate(value: true)
//		let  timeSort : NSSortDescriptor? // = NSSortDescriptor(key: "modifiedTimestamp", ascending: true)

		queryFor(type.cloudKitType, with: predicate, properties: nil, sortedBy: nil, batchSize: 250) { record, error in
			if  let ckRecord = record {
				ckRecords.append(ckRecord)
			} else { // after all records have arrived
				closure?(ckRecords)
			}
		}
	}

}

extension String {

	var            cloudKitType : String  { return "CD_" + self }
	var          repositoryPath : String  { return repositoryURL.path }
	var       dataExtensionPath : String? { return dataExtensionURL?.path }
	var       dataExtensionURL  : URL?    { return URL(string: gDataDirectoryName)?.appendingPathComponent(self) }
	var          repositoryURL  : URL     { return gFilesURL.appendingPathComponent(self) }

	func migrateTo(_ to: String?) {
		do {
			let temporary = "delete me"

			try           moveItem(to: temporary) // in case to is inside from, in which case the file manager will throw (move self inside self, a no can do)
			try temporary.moveItem(to: to)
		} catch {
			printDebug(.dError, "\(error)")
		}
	}

	func moveItem(to: String?) throws {
		if  let toPath = to?.repositoryPath {
			let   path = repositoryPath
			let      m = gFileManager

			if          m.fileExists(atPath: path) {
				if      m.fileExists(atPath: toPath) {
					try m.removeItem(atPath: toPath)
				}

				try     m.moveItem  (atPath: path, toPath: toPath)
			}
		}
	}

}
