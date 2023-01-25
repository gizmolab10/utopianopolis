//
//  ZCoreDataStack.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/3/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

struct ZDeferral {
	let closure : Closure?         // for deferralHappensMaybe to invoke
	let    opID : ZCDOperationID   // so status text can show it
}

struct ZEntityDescriptor {
	let entityName : String
	let recordName : String?
	let databaseID : ZDatabaseID
}

struct ZExistence {
	var zRecord : ZRecord? = nil
	var closure : ZRecordClosure?
	let  entity : ZEntityDescriptor?
	let    file : ZFileDescriptor?
}

enum ZCDMigrationState: Int {
	case firstTime
	case migrateFileData
	case normal
}

enum ZCDOperationID: Int {
	case oLoad
	case oSave
	case oFetch
	case oSearch
	case oAssets
	case oProgeny
	case oExistence

	var description : String {
		var string = "\(self)".lowercased().substring(fromInclusive: 1)

		switch self {
			case .oProgeny:   return   "loading " + string
			case .oExistence: string = "checking exist"
			case .oSave:      string = "sav"
			default:          break
		}

		return string + "ing local data"
	}
}

typealias ZExistenceArray      =        [ZExistence]
typealias ZExistenceDictionary = [String:ZExistenceArray]

extension ZExistenceArray {

	func fireClosures() {
		var counter = [ZDatabaseID : Int]()

		func count(_ r: ZRecord?) {
			if  let i = r?.databaseID {
				if  let x = counter[i] {
					counter[i] = x + 1
				} else {
					counter[i] = 1
				}
			}
		}

		for e in self {
			if  let close = e.closure {
				let     r = e.zRecord

				count(r)
				close(r)   // invoke closure
			}
		}

		for (i, x) in counter {
			printDebug(.dExist, "\(i.identifier) ! \(x)")
		}
	}

	mutating func updateClosureForZRecord(_ zRecord: ZRecord, of type: String) {
		let name = (type == kFileType) ? (zRecord as? ZFile)?.name : (zRecord.recordName)

		for (index, e) in enumerated() {
			var ee = e

			if  name == e.file?.name || name == e.entity?.recordName {
				ee.zRecord  = zRecord
				self[index] = ee
			}
		}
	}

	func predicate(_ type: String) -> NSPredicate {
		let    isFile = type == kFileType
		let   keyPath = isFile ? "name" : "recordName"
		var     items = kEmpty
		var separator = kEmpty

		for e in self {
			if  isFile {
				if  let  file = e.file,
					let  name = file.name {
					items.append("\(separator)'\(name)'")
					separator = kCommaSeparator
				}
			} else {
				if  let entity = e.entity,
					let   name = entity.recordName {
					items.append("\(separator)'\(name)'")
					separator  = kCommaSeparator
				}
			}
		}

		let format = "\(keyPath) in { \(items) }"

		return NSPredicate(format: format)
	}
}

func gLoadContext(into dbID: ZDatabaseID, onCompletion: AnyClosure? = nil) { gCoreDataStack.loadContext(into: dbID, onCompletion: onCompletion) }
func gSaveContext()                                                        { gCoreDataStack.saveContext() }
let  gCoreDataStack  = ZCoreDataStack()
var  gCoreDataIsBusy : Bool  { return gCoreDataStack.currentOpID != nil }
let  gCoreDataURL    : URL = { return gFilesURL.appendingPathComponent("data") }()
var  gCDCurrentBackgroundContext: NSManagedObjectContext { return gCoreDataStack.context }

class ZCoreDataStack: NSObject {

	var existenceClosures = [ZDatabaseID : ZExistenceDictionary]()
	var   fetchedRegistry = [ZDatabaseID : [String : ZManagedObject]]()
	var   missingRegistry = [ZDatabaseID : StringsArray]()
	var     deferralStack = [ZDeferral]()
	let          localURL = gCoreDataURL.appendingPathComponent("local.store")
	let         publicURL = gCoreDataURL.appendingPathComponent("cloud.public.store")
	let        privateURL = gCoreDataURL.appendingPathComponent("cloud.private.store")
	lazy var        model : NSManagedObjectModel           = { return NSManagedObjectModel.mergedModel(from: nil)! }()
	lazy var   localStore : NSPersistentStore?             = { return persistentStore(for: localURL) }()
	lazy var  publicStore : NSPersistentStore?             = { return persistentStore(for: publicURL) }()
	lazy var privateStore : NSPersistentStore?             = { return persistentStore(for: privateURL) }()
	lazy var  coordinator : NSPersistentStoreCoordinator?  = { return persistentContainer.persistentStoreCoordinator }()
	lazy var      context : NSManagedObjectContext         = { return persistentContainer.viewContext }()
	var          isDoneOp : Bool                             { return currentOpID == nil }
	var        statusText : String?                          { return statusOpID?.description }
	var        statusOpID : ZCDOperationID?                  { return currentOpID ?? deferralStack.first?.opID }
	var       currentOpID : ZCDOperationID?
	func persistentStore(for url: URL) -> NSPersistentStore? { return coordinator?.persistentStore(for: url) }

	func hasStore(for databaseID: ZDatabaseID = .mineID) -> Bool {
		if  gIsUsingCoreData {
			let       request = NSFetchRequest<NSFetchRequestResult>(entityName: kZoneType)
			request.predicate = dbidPredicate(from: databaseID)

			do {
				let flag = try context.count(for: request) > 10

				return flag
			} catch {
			}
		}

		return false
	}

	// MARK: - save
	// MARK: -

	func saveContext() {
		if  gCanSave, gIsReadyToShowUI { // , !gIsUsingCloudKit, false {
			deferUntilAvailable(for: .oSave) {
				FOREBACKGROUND { [self] in
					if  context.hasChanges {
						checkCrossStore()

						do {
							try context.save()
						} catch {
							print(error)
						}
					}

					makeAvailable()
				}
			}
		}
	}

	// MARK: - load
	// MARK: -

	func loadContext(into dbID: ZDatabaseID, onCompletion: AnyClosure?) {
		if !gCanLoad {
			onCompletion?(0)
		} else {
			deferUntilAvailable(for: .oLoad) {
				FOREGROUND { [self] in
					load(type: kManifestType, into: dbID, onlyOne: false)

					var roots = [kRootName, kTrashName, kDestroyName, kLostAndFoundName]

					if  dbID == .mineID {
						roots = [kFavoritesRootName] + roots
					}

					for root in roots {
						loadRootZone(recordName: root, into: dbID)
					}

					load(type: kFileType, into: dbID, onlyOne: false)

					FOREGROUND { [self] in
						makeAvailable()
						onCompletion?(0)
					}
				}
			}
		}
	}

	func loadRootZone(recordName: String, into dbID: ZDatabaseID) {
		if  let zRecords = gRemoteStorage.zRecords(for: dbID) {
			let  fetched = load(type: kZoneType, recordName: recordName, into: dbID)

			for object in fetched {
				if  let zone = object as? Zone {
					let oid = object.objectID
					zone.respectOrder()

					FOREGROUND {
						if  let root = self.context.object(with: oid) as? Zone {
							zRecords.setRoot(root, for: recordName.rootID)
						}
					}
				}
			}
		}
	}

	// called by load recordName and find type, recordName
	// fetch, extract data, register

	@discardableResult func load(type: String, recordName: String = kEmpty, into dbID: ZDatabaseID, onlyOne: Bool = true) -> ZManagedObjectsArray {
		let objects = fetch(type: type, recordName: recordName, into: dbID, onlyOne: onlyOne)

		invokeUsingDatabaseID(dbID) {
			let ids = objects.map { $0.objectID }
			for id in ids {
				FOREGROUND() { [self] in
					let      object = context.object(with: id)
					if  let zRecord = object as? ZRecord {
						zRecord.convertFromCoreData(visited: [])
						zRecord.register()
					}
				}
			}
		}

		return objects
	}

	func loadFile(for descriptor: ZFileDescriptor) -> ZFile? {
		if  let name = descriptor.name,
			let type = descriptor.type,
			let dbID = descriptor.dbID {
			let       request = NSFetchRequest<NSFetchRequestResult>(entityName: kFileType)
			request.predicate = NSPredicate(format: "name = %@ AND type = %@", name, type, dbID.identifier).and(dbidPredicate(from: dbID))
			let      zRecords = fetchUsing(request: request)

			for zRecord in zRecords {
				if  let    file = zRecord as? ZFile {
					return file
				}
			}
		}

		return nil
	}

	// MARK: - registry
	// MARK: -

	func registerObject(_ objectID: NSManagedObjectID, recordName: String, dbID: ZDatabaseID) {
		let object = context.object(with: objectID)
		var dict   = fetchedRegistry[dbID]
		if  dict  == nil {
			dict   = [String : ZManagedObject]()
		}

		dict?[recordName]     = object
		fetchedRegistry[dbID] = dict

		(object as? ZRecord)?.register() // for records read from file 
	}

	func missingFrom(_ dbID: ZDatabaseID) -> StringsArray {
		var missing  = missingRegistry[dbID]
		if  missing == nil {
			missing  = StringsArray()
		}

		return missing!
	}

	func registerAsMissing(recordName: String, dbID: ZDatabaseID) {
		var missing = missingFrom(dbID)

		missing.appendUnique(item: recordName)

		missingRegistry[dbID] = missing
	}

	func isMissing(recordName: String, from dbID: ZDatabaseID) -> Bool {
		return !missingFrom(dbID).contains(recordName)
	}

	func resolveMissing(from dbID: ZDatabaseID) {
		var missing         = missingFrom(dbID)
		for name in missing {
			let found       = find(type: kZoneType, recordName: name, in: dbID, trackMissing: false)
			if  found.count > 0,
				let   index = missing.firstIndex(of: name) {
				missing.remove(at: index)
			}
		}

		missingRegistry[dbID] = missing
	}

	// MARK: - search
	// MARK: -

	func fetchChildrenOf(_ recordName: String, in dbID: ZDatabaseID) -> ZoneArray? {
		let       request = NSFetchRequest<NSFetchRequestResult>(entityName: kZoneType)
		request.predicate = fetchChildrenPredicate(recordName: recordName, into: dbID)

		return fetchUsing(request: request, onlyOne: false) as? ZoneArray
	}

	func find(type: String, recordName: String, in dbID: ZDatabaseID, onlyOne: Bool = true, trackMissing: Bool = true) -> ZManagedObjectsArray {
		let           dbid = dbID == .everyoneID ? dbID : .mineID
		if  let     object = fetchedRegistry[dbid]?[recordName], !object.isPublicRootDefault(recordName: recordName, into: dbid) {
			return [object]
		}

		if  trackMissing, missingFrom(dbid).contains(recordName) {
			return []
		}

		return fetch(type: type, recordName: recordName, into: dbid, onlyOne: onlyOne)
	}

	func fetchUsing(request: NSFetchRequest<NSFetchRequestResult>, onlyOne: Bool = true) -> ZManagedObjectsArray {
		var   objects = ZManagedObjectsArray()

		do {
			let items = try context.fetch(request)
			for item in items {
				if  let object = item as? ZManagedObject {

					objects.append(object)

//					if  let        zRecord = object as? ZRecord,
//						let       ckRecord = persistentContainer.record(for: object.objectID) {
//						zRecord.recordName = ckRecord.recordID.recordName
//					}

					if  onlyOne {

						// //////////////////////////////////////////////////////////////////////////////// //
						// NOTE: all but the first of multiple values found are duplicates and thus ignored //
						// //////////////////////////////////////////////////////////////////////////////// //

						break
					}
				}
			}
		} catch {
			print(error)
		}

		return objects
	}

	// must call this on foreground thread
	// else throws mutate while enumerate error

	func fetch(type: String, recordName: String = kEmpty, into dbID: ZDatabaseID, onlyOne: Bool = true) -> ZManagedObjectsArray {
		var objects       = ZManagedObjectsArray()
		let request       = fetchRequest(type: type, recordName: recordName, into: dbID)
		var items         = fetchUsing(request: request, onlyOne: false)
		if  items.count  == 0 {
			registerAsMissing(recordName: recordName, dbID: dbID)
		} else {
			if !onlyOne {
				for item in items {
					objects.append(item)
				}
			} else {
				while items.count > 0 {
					if  let object = items.last {
						if  object.isPublicRootDefault(recordName: recordName, into: dbID) {
							items.removeLast()
						} else {
							objects.append(object)

							break
						}
					} else {
						break
					}
				}
			}

			let ids = objects.map { $0.objectID }

			FOREGROUND(forced: true) { [self] in
				for id in ids {
					registerObject(id, recordName: recordName, dbID: dbID)
				}
			}
		}

		return objects
	}

	func searchZRecordsForNames(_ names: StringsArray, within dbID: ZDatabaseID, onCompletion: StringZRecordsDictionaryClosure? = nil) {
		var result = StringZRecordsDictionary()

		if !gIsReadyToShowUI || !gCanLoad {
			onCompletion?(result)
		} else {
			let searchables = names.map { $0.searchable }.filter { $0 != kSpace }
			let dbPredicate = dbidPredicate(from: dbID)
			let    entities = [kTraitType, kZoneType]
			var       count = searchables.count * entities.count

			for searchable in searchables {
				for entity in entities {
					if  let predicate = searchPredicate(entityName: entity, string: searchable) {
						search(within: dbID, entityName: entity, using: predicate.and(dbPredicate)) { matches in
							if  matches.count > 0 {
								result[searchable] = matches.appending(result[searchable])
							}

							count     -= 1
							if  count == 0 {
								onCompletion?(result)
							}
						}
					}
				}
			}
		}
	}

	func search(within dbID: ZDatabaseID, entityName: String, using predicate: NSPredicate, onCompletion: ZRecordsClosure? = nil) {
		if !gCanLoad || !gIsReadyToShowUI {
			onCompletion?(ZRecordsArray())
		} else {
			let       request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
			request.predicate = predicate.and(dbidPredicate(from: dbID))

			deferUntilAvailable(for: .oSearch) { [self] in
				persistentContainer.performBackgroundTask { [self] context in
					var objectIDs = ZObjectIDsArray()
					do {
						let items = try context.fetch(request)
						for item in items {
							if  let object = item as? ZManagedObject {
								objectIDs.append(object.objectID)
							}
						}

//						try context.save()
					} catch {
						print("search fetch failed")
					}

					makeAvailable() // before calling closure

					FOREGROUND { [self] in
						onCompletion?(ZRecordsArray.createFromObjectIDs(objectIDs, in: persistentContainer.viewContext))
					}
				}
			}
		}
	}

	// MARK: - internals
	// MARK: -

	func persistentStore(for databaseID: ZDatabaseID) -> NSPersistentStore? {
		switch databaseID {
			case .everyoneID: return  publicStore
			default:          return privateStore
		}
	}

	lazy var localDescription: NSPersistentStoreDescription = {
		let           desc = NSPersistentStoreDescription(url: localURL)
		desc.configuration = "Local"

		return desc
	}()

	lazy var privateDescription: NSPersistentStoreDescription = {
		let                          desc = NSPersistentStoreDescription(url: privateURL)
		desc.configuration                = "Private"

		desc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

		if  gIsUsingCloudKit {
			let                   options = NSPersistentCloudKitContainerOptions(containerIdentifier: kCloudID)
			desc.cloudKitContainerOptions = options
		}

		return desc
	}()

	lazy var publicDescription: NSPersistentStoreDescription = {
		let                          desc = NSPersistentStoreDescription(url: publicURL)
		desc.configuration                = "Public"

		desc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

		if  gIsUsingCloudKit {
			let                   options = NSPersistentCloudKitContainerOptions(containerIdentifier: kCloudID)
			options.databaseScope         = CKDatabase.Scope.public // default is private. needs osx v11.0
			desc.cloudKitContainerOptions = options
		}

		return desc
	}()

	lazy var persistentContainer: NSPersistentCloudKitContainer = {
		let container = NSPersistentCloudKitContainer(name: "seriously", managedObjectModel: model)

		ValueTransformer.setValueTransformer(  ZReferenceTransformer(), forName:   gReferenceTransformerName)
		ValueTransformer.setValueTransformer( ZAssetArrayTransformer(), forName:  gAssetArrayTransformerName)
		ValueTransformer.setValueTransformer(ZStringArrayTransformer(), forName: gStringArrayTransformerName)

		// Update the container's list of store descriptions
		container.persistentStoreDescriptions = [
			privateDescription,
			publicDescription,
			localDescription
		]

		container.loadPersistentStores() { (storeDescription, iError) in
			if  let error = iError as NSError? {
				fatalError("Unresolved error \(error), \(error.userInfo)")
			}
		}

		if  gIsUsingCloudKit, gCDMigrationState != .normal {
			do {
				try container.initializeCloudKitSchema()
			} catch {
				print(error)
			}
		}

		container.viewContext.automaticallyMergesChangesFromParent = true
		container.viewContext.mergePolicy                          = NSMergePolicy(merge: .overwriteMergePolicyType)

		return container
	}()

	// MARK: - core data prefers one operation at a time
	// MARK: -

	func isAvailable(for opID: ZCDOperationID) -> Bool { return currentOpID == nil || currentOpID == opID }
	func makeAvailable()                               {        currentOpID  = nil }

	func invokeDeferralMaybe(_ iTimerID: ZTimerID?) {
		if  currentOpID == nil {                  // nil means core data is no longer doing anything
			if  deferralStack.count == 0 {        // check if anything is deferred
				gTimers.stopTimer(for: iTimerID)  // do not fire again, closure is no longer invoked
			} else {
				let waiting = deferralStack.remove(at: 0)
				currentOpID = waiting.opID

				gSignal([.spDataDetails])         // tell data detail view about it
				waiting.closure?()                // do what was deferred
			}
		}
	}

	func deferUntilAvailable(for opID: ZCDOperationID, _ onAvailable: @escaping Closure) {
		if  currentOpID == nil {
			currentOpID  = opID

			onAvailable()
		} else {
			for deferred in deferralStack {
				if  deferred.opID == opID {
					return // this op is already deferred
				}
			}

			deferralStack.append(ZDeferral(closure: onAvailable, opID: opID))

			gTimers.startTimer(for: .tCoreDataDeferral)
		}
	}

	// MARK: - internal
	// MARK: -

	func   zoneNamePredicate(from string:          String) -> NSPredicate { return NSPredicate(format: "zoneName contains[cd] %@",   string.lowercased()) }
	func      traitPredicate(from string:          String) -> NSPredicate { return NSPredicate(format:     "text contains[cd] %@",   string.lowercased()) }
	func recordNamePredicate(from recordName:      String) -> NSPredicate { return NSPredicate(format:          "recordName = %@",            recordName) }
	func     parentPredicate(from recordName:      String) -> NSPredicate { return NSPredicate(format:           "parentRID = %@",            recordName) }
	func       dbidPredicate(from databaseID: ZDatabaseID) -> NSPredicate { return NSPredicate(format:                "dbid = %@", databaseID.identifier) }

	func fetchRequest(type: String, recordName: String, into dbID: ZDatabaseID, onlyOne: Bool = true) -> NSFetchRequest<NSFetchRequestResult> {
		let       request = NSFetchRequest<NSFetchRequestResult>(entityName: type)
		request.predicate = fetchPredicate(type: type, recordName: recordName, into: dbID)

		return request
	}

	func fetchPredicate(type: String, recordName: String, into dbID: ZDatabaseID, onlyOne: Bool = true) -> NSPredicate {
		let             r = recordNamePredicate(from: recordName)
		let             d =       dbidPredicate(from: dbID)
		return !onlyOne ? d : type == kUserType ? r : r.and(d)
	}

	func fetchChildrenPredicate(recordName: String, into dbID: ZDatabaseID) -> NSPredicate {
		let r = parentPredicate(from: recordName)
		let d =   dbidPredicate(from: dbID)
		return r.and(d)
	}

	func searchPredicate(entityName: String, string: String?) -> NSPredicate? {
		if  let s = string {
			switch entityName {
				case kZoneType:  return zoneNamePredicate(from: s)
				case kTraitType: return traitPredicate   (from: s)
				default:         break
			}
		}

		return nil
	}
//
//	func searchPredicate(entityNames: StringsArray, string: String) -> NSPredicate? {
//		var predicate: NSPredicate?
//		for entityName in entityNames {
//			if  let subpredicate = searchPredicate(entityName: entityName, string: string) {
//				if  let     p = predicate {
//					predicate = p.or(subpredicate)
//				} else {
//					predicate = subpredicate
//				}
//			}
//		}
//
//		return predicate != nil ? predicate! : NSPredicate(value: true)
//	}
//
//	func searchPredicate(entityName: String, strings: StringsArray) -> NSPredicate? {
//		switch entityName {
//			case kZoneType:  return zoneNamePredicate(from: strings)
//			case kTraitType: return traitPredicate   (from: strings)
//			default:         return nil
//		}
//	}
//
//	func predicateFrom(_ strings: StringsArray, _ onEach: StringToPredicateClosure) -> NSPredicate {
//		var predicate: NSPredicate?
//		for string in strings {
//			let subpredicate = onEach(string)
//
//			if  let     p = predicate {
//				predicate = p.or(subpredicate)
//			} else {
//				predicate = subpredicate
//			}
//		}
//
//		return predicate != nil ? predicate! : NSPredicate(value: true)
//	}
//
//	func zoneNamePredicate(from strings: StringsArray) -> NSPredicate {
//		return predicateFrom(strings) { string in
//			return zoneNamePredicate(from: string)
//		}
//	}
//
//	func traitPredicate(from strings: StringsArray) -> NSPredicate {
//		return predicateFrom(strings) { string in
//			return traitPredicate(from: string)
//		}
//	}

	func existencePredicate(entityName: String, recordName: String?, databaseID: ZDatabaseID) -> NSPredicate? {
		if  let          name = recordName {
			let   dbPredicate = dbidPredicate(from: databaseID)
			let namePredicate = recordNamePredicate(from: name)

			if  entityName == kUserEntityName {
				return namePredicate
			}

			return namePredicate.and(dbPredicate)
		}

		return nil
	}

	func hasExisting(entityName: String, recordName: String?, databaseID: ZDatabaseID) -> Any? {
		if  isAvailable(for: .oFetch),         // avoid crash due to core data fetch array being simultaneously mutated and enumerated
			let     predicate = existencePredicate(entityName: entityName, recordName: recordName, databaseID: databaseID) {
			let       request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
			request.predicate = predicate

			do {
				let     items = try context.fetch(request)
				currentOpID   = nil

				if  items.count > 0 {
					return items[0]
				}
			} catch {

			}
		}

		return nil
	}

	func checkCrossStore() {
		if  gPrintModes.contains(.dCross) {
			for updated in context.updatedObjects {
				if  let  zone  = updated as? Zone,
					let zdbid  = zone.dbid,
					let pdbid  = zone.parentZone?.dbid {
					if  zdbid != pdbid {
						printDebug(.dCross, "\(zone)")
					}
				}
			}
		}
	}

	// MARK: - existence closures
	// MARK: -

	func setClosures(_ closures: ZExistenceArray, for entityName: String, dbID: ZDatabaseID) {
		var dict  = existenceClosures[dbID]
		if  dict == nil {
			dict  = ZExistenceDictionary()
		}

		dict?      [entityName] = closures
		existenceClosures[dbID] = dict!
	}

	func closures(for entityName: String, dbID: ZDatabaseID) -> ZExistenceArray {
		var d  = existenceClosures[dbID]
		var c  = d?[entityName]
		if  d == nil {
			d  = ZExistenceDictionary()
		}

		if  c == nil {
			c  = ZExistenceArray()
			d?[entityName] = c!
		}

		existenceClosures[dbID] = d!

		return c!
	}

	func processClosures(for  entityName: String, dbID: ZDatabaseID, _ onCompletion: IntClosure?) {
		var array = closures(for: entityName, dbID: dbID)

		if  array.count == 0 {
			onCompletion?(0)
		} else {
			let         count = "\(array.count)".appendingSpacesToLength(6)
			let       request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
			request.predicate = array.predicate(entityName)

			printDebug(.dExist, "\(dbID.identifier) = \(count)\(entityName)")

			deferUntilAvailable(for: .oExistence) {
				FOREBACKGROUND { [self] in
					do {
						let items = try context.fetch(request)

						FOREGROUND { [self] in
							for item in items {
								if  let zRecord = item as? ZRecord {           // insert zrecord into closures
									array.updateClosureForZRecord(zRecord, of: entityName)
									zRecord.needAdoption()
								}
							}

							array.fireClosures()
							setClosures([], for: entityName, dbID: dbID)
							makeAvailable()
							onCompletion?(0)
						}
					} catch {

					}
				}
			}
		}
	}

	func finishCreating(for dbID: ZDatabaseID, _ onCompletion: IntClosure?) {
		guard let dict = existenceClosures[dbID] else {
			onCompletion?(0) // so next operation can begin

			return
		}

		let entityNames = dict.map { $0.key }
		let  firstIndex = entityNames.count - 1

		func processForEntityName(at index: Int) {
			if  index < 0 {
				onCompletion?(0)                                       // exit recursive loop and let next operation begin
			} else {
				let entityName = entityNames[index]

				processClosures(for: entityName, dbID: dbID) { value in
					processForEntityName(at: index - 1)                // recursive while loop
				}
			}
		}

		processForEntityName(at: firstIndex)
	}

	// MARK: - vaccuum
	// MARK: -

	func emptyZones(within dbID: ZDatabaseID, onCompletion: ZRecordsClosure? = nil) {
		let predicate = zoneNamePredicate(from: "NULL")
		search(within: dbID, entityName: kZoneType, using: predicate) { matches in
			onCompletion?(matches)
		}
	}

	func removeAllDuplicatesOf(_ zRecord: ZRecord) {
		if  let      dbid = zRecord.dbid,
			let      dbID = ZDatabaseID(rawValue: dbid),
			let      name = zRecord.recordName {
			let predicate = recordNamePredicate(from: name)

			search(within: dbID, entityName: kZoneType, using: predicate) { zRecords in
				let  count = zRecords.count
				let extras = zRecords.filter() { $0 != zRecord }

				if  count > extras.count {
					FOREGROUND {
						for extra in extras {
							extra.unregister()
							gCDCurrentBackgroundContext.delete(extra)
						}
					}
				}
			}
		}
	}

}
