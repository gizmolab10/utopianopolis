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

enum ZCDStoreScope: String {

	case sLocal   = "Local"
	case sPublic  = "Public"
	case sPrivate = "Private"

	static var all: [ZCDStoreScope] { return [.sLocal, .sPublic, .sPrivate] }

	var lastComponent: String {
		var last  = rawValue.lowercased()
		if  self != .sLocal {
			last  = "cloud." + last
		}

		return last + ".store"
	}

}

let  gCoreDataStack                                = ZCoreDataStack()
var  gCDCurrentBackgroundContext                   : NSManagedObjectContext? { return gCoreDataStack.context }
var  gCoreDataIsBusy                                                  : Bool { return gCoreDataStack.currentOpID != nil }
func gDataURLAt(_ lastPathComponent: String)                          -> URL { return gFilesURL.appendingPathComponent(lastPathComponent) }
func gUrlFor(_ type: ZCDStoreScope, at lastPathComponent: String)     -> URL { return gDataURLAt(lastPathComponent).appendingPathComponent(type.lastComponent) }
func gLoadContext(into dbID: ZDatabaseID, onCompletion: AnyClosure? = nil)   { gCoreDataStack.loadContext(into: dbID, onCompletion: onCompletion) }
func gSaveContext()                                                          { gCoreDataStack.saveContext() }

class ZCoreDataStack: NSObject {

	var   existenceClosures = [ZDatabaseID : ZExistenceDictionary]()
	var     fetchedRegistry = [ZDatabaseID : ZManagedObjectsDictionary]()
	var     missingRegistry = [ZDatabaseID : StringsArray]()
	var       deferralStack = [ZDeferral]()
	var persistentContainer : NSPersistentCloudKitContainer?
	var         currentOpID : ZCDOperationID?
	var          statusOpID : ZCDOperationID?                 { return currentOpID ?? deferralStack.first?.opID }
	var            isDoneOp : Bool                            { return currentOpID == nil }
	var          statusText : String?                         { return statusOpID?.description }
	lazy var    coordinator : NSPersistentStoreCoordinator? = { return persistentContainer?.persistentStoreCoordinator } ()
	lazy var        context : NSManagedObjectContext?       = { return persistentContainer?.viewContext }                ()
	lazy var          model : NSManagedObjectModel          = { return NSManagedObjectModel.mergedModel(from: nil)! }    ()

	func persistentStore(for type: ZCDStoreScope, at pathComponent: String) -> NSPersistentStore? {
		return coordinator?.persistentStore(for: gUrlFor(type, at: pathComponent))
	}

	func hasStore(for databaseID: ZDatabaseID = .mineID) -> Bool {
		if  gIsUsingCoreData,
			let             c = context {
			let       request = NSFetchRequest<NSFetchRequestResult>(entityName: kZoneType)
			request.predicate = dbidPredicate(from: databaseID)

			do {
				let flag = try c.count(for: request) > 10

				return flag
			} catch {
			}
		}

		return false
	}

	// MARK: - save
	// MARK: -

	func saveContext() {
		if  gCanSave, gIsReadyToShowUI {
			deferUntilAvailable(for: .oSave) {
				FOREBACKGROUND { [self] in
					if  let c = context, c.hasChanges {
						checkCrossStore()

						do {
							try c.save()
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
						if  let root = self.context?.object(with: oid) as? Zone {
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
					let      object = context?.object(with: id)
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
		if  let            name = descriptor.name,
			let            type = descriptor.type,
			let            dbID = descriptor.dbID {
			let         request = NSFetchRequest<NSFetchRequestResult>(entityName: kFileType)
			request  .predicate = NSPredicate(format: "name = %@ AND type = %@", name, type, dbID.identifier).and(dbidPredicate(from: dbID))
			let        zRecords = fetchUsing(request: request)

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
		if  let object = context?.object(with: objectID) {
			var dict   = fetchedRegistry[dbID]
			if  dict  == nil {
				dict   = ZManagedObjectsDictionary()
			}

			dict?[recordName]     = object
			fetchedRegistry[dbID] = dict

			(object as? ZRecord)?.register() // for records read from file
		}
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
			if  let items = try context?.fetch(request) {
				for item in items {
					if  let object = item as? ZManagedObject {

						objects.append(object)

						if  onlyOne {

							// //////////////////////////////////////////////////////////////////////////////// //
							// NOTE: all but the first of multiple values found are duplicates and thus ignored //
							// //////////////////////////////////////////////////////////////////////////////// //

							break
						}
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
		let items         = fetchUsing(request: request, onlyOne: onlyOne)
		if  items.count  == 0 {
			registerAsMissing(recordName: recordName, dbID: dbID)
		} else {
			for item in items {
				objects.append(item)
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
		} else if let       c = persistentContainer {
			let       request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
			request.predicate = predicate.and(dbidPredicate(from: dbID))

			deferUntilAvailable(for: .oSearch) { [self] in
				c.performBackgroundTask { [self] context in
					var objectIDs = ZObjectIDsArray()
					do {
						let items = try context.fetch(request)
						for item in items {
							if  let object = item as? ZManagedObject,
								object.isActualChild {
								objectIDs.append(object.objectID)
							}
						}

						//						try context.save()
					} catch {
						print("search fetch failed")
					}

					makeAvailable() // before calling closure

					FOREGROUND {
						onCompletion?(ZRecordsArray.createFromObjectIDs(objectIDs, in: c.viewContext))
					}
				}
			}
		}
	}

	// MARK: - internals
	// MARK: -

	func persistentStore(for databaseID: ZDatabaseID, at pathComponent: String) -> NSPersistentStore? {
		switch databaseID {
			case .everyoneID: return persistentStore(for:  .sPublic, at: pathComponent)
			default:          return persistentStore(for: .sPrivate, at: pathComponent)
		}
	}

	func storeDescription(cloudID: ZCDCloudID, at pathComponent: String, for type: ZCDStoreScope) -> NSPersistentStoreDescription{
		let desc = NSPersistentStoreDescription(url: gUrlFor(type, at: pathComponent))
		desc.configuration = type.rawValue

		if  type != .sLocal {
			desc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

			if  gIsUsingCloudKit {
				let                   options = NSPersistentCloudKitContainerOptions(containerIdentifier: gCDCloudID.cloudID)

				if  type == .sPublic {
					options.databaseScope     = CKDatabase.Scope.public // default is private. needs osx v11.0
				}

				desc.cloudKitContainerOptions = options
			}
		}

		return desc
	}

	func getPersistentContainer(cloudID: ZCDCloudID, at lastPathComponent: String) -> NSPersistentCloudKitContainer {
		let     container = NSPersistentCloudKitContainer(name: "seriously", managedObjectModel: model)

		ValueTransformer.setValueTransformer(  ZReferenceTransformer(), forName:   gReferenceTransformerName)
		ValueTransformer.setValueTransformer( ZAssetArrayTransformer(), forName:  gAssetArrayTransformerName)
		ValueTransformer.setValueTransformer(ZStringArrayTransformer(), forName: gStringArrayTransformerName)

		container.persistentStoreDescriptions = [
			storeDescription(cloudID: cloudID, at: lastPathComponent, for: .sPrivate),
			storeDescription(cloudID: cloudID, at: lastPathComponent, for: .sPublic),
			storeDescription(cloudID: cloudID, at: lastPathComponent, for: .sLocal)
		]

		container.loadPersistentStores() { (storeDescription, iError) in
			if  let error = iError as NSError? {
				fatalError("Unresolved error \(error), \(error.userInfo)")
			}
		}

		container.viewContext.automaticallyMergesChangesFromParent = true
		container.viewContext.mergePolicy                          = NSMergePolicy(merge: .overwriteMergePolicyType)

		return container
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

	func checkCrossStore() {
		if  let c = context, gPrintModes.contains(.dCross) {
			for updated in c.updatedObjects {
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
							gCDCurrentBackgroundContext?.delete(extra)
						}
					}
				}
			}
		}
	}

}
