//
//  ZCoreDataStack.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/3/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

func gLoadContext(into dbID: ZDatabaseID?, onCompletion: AnyClosure? = nil) { gCoreDataStack.loadContext(into: dbID, onCompletion: onCompletion) }
func gSaveContext()                                                         { gCoreDataStack.saveContext() }
let  gCoreDataStack  = ZCoreDataStack()
var  gCoreDataIsBusy : Bool  { return gCoreDataStack.currentOpID != nil }
let  gCoreDataURL    : URL = { return gFilesURL.appendingPathComponent("data") }()

struct ZDeferral {
	let closure : Closure?         // for deferralHappensMaybe to invoke
	let    opID : ZCDOperationID   // so status text can show it
}

struct ZEntityDescriptor {
	let entityName : String
	let recordName : String?
	let databaseID : ZDatabaseID?
}

struct ZExistence {
	var zRecord : ZRecord? = nil
	var closure : ZRecordClosure?
	let  entity : ZEntityDescriptor?
	let    file : ZFileDescriptor?
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
		let name = (type == kFileType) ? (zRecord as? ZFile)?.name : (zRecord.ckRecordName ?? zRecord.recordName)

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
		var     items = ""
		var separator = ""

		for e in self {
			if  isFile {
				if  let  file = e.file,
					let  name = file.name {
					items.append("\(separator)'\(name)'")
					separator = ","
				}
			} else {
				if  let entity = e.entity,
					let   name = entity.recordName {
					items.append("\(separator)'\(name)'")
					separator  = ","
				}
			}
		}

		let format = "\(keyPath) in { \(items) }"

		return NSPredicate(format: format)
	}
}

class ZCoreDataStack: NSObject {

	var existenceClosures = [ZDatabaseID : ZExistenceDictionary]()
	var   fetchedRegistry = [ZDatabaseID : [String : ZManagedObject]]()
	var     deferralStack = [ZDeferral]()
	let          localURL = gCoreDataURL.appendingPathComponent("local.store")
	let         publicURL = gCoreDataURL.appendingPathComponent("cloud.public.store")
	let        privateURL = gCoreDataURL.appendingPathComponent("cloud.private.store")
	lazy var        model : NSManagedObjectModel          = { return NSManagedObjectModel.mergedModel(from: nil)! }()
	lazy var   localStore : NSPersistentStore?            = { return persistentStore(for: localURL) }()
	lazy var  publicStore : NSPersistentStore?            = { return persistentStore(for: publicURL) }()
	lazy var privateStore : NSPersistentStore?            = { return persistentStore(for: privateURL) }()
	lazy var  coordinator : NSPersistentStoreCoordinator? = { return persistentContainer.persistentStoreCoordinator }()
	var    managedContext : NSManagedObjectContext          { return persistentContainer.viewContext }
	var          isDoneOp : Bool                            { return currentOpID == nil }
	var        statusText : String?                         { return statusOpID?.description }
	var        statusOpID : ZCDOperationID?                 { return currentOpID ?? deferralStack.first?.opID }
	var       currentOpID : ZCDOperationID?

	// MARK:- save
	// MARK:-

	func saveContext() {
		if  gCanSave, gIsReadyToShowUI {
			self.deferUntilAvailable(for: .oSave) {
				BACKGROUND {
					let context = self.managedContext
					if  context.hasChanges {
						self.checkCrossStore()

						do {
							try context.save()
						} catch {
							print(error)
						}
					}

					self.makeAvailable()
				}
			}
		}
	}

	// MARK:- registry
	// MARK:-

	func register(_ object: ZManagedObject, recordName: String, dbID: ZDatabaseID) {
		var dict  = fetchedRegistry[dbID]
		if  dict == nil {
			dict  = [String : ZManagedObject]()
		}

		dict?[recordName]     = object
		fetchedRegistry[dbID] = dict
	}

	func find(type: String, with recordName: String, into dbID: ZDatabaseID, onlyOne: Bool = true) -> [ZManagedObject] {
		if  let     object = fetchedRegistry[dbID]?[recordName] {
			return [object]
		}

		return fetch(type: type, with: recordName, into: dbID, onlyOne: onlyOne)
	}

	// must call this on foreground thread
	// else throws mutate while enumerate error

	func fetch(type: String, with recordName: String, into dbID: ZDatabaseID?, onlyOne: Bool = true) -> [ZManagedObject] {
		var           objects = [ZManagedObject]()
		if  let          dbid = dbID?.identifier {
			let       request = NSFetchRequest<NSFetchRequestResult>(entityName: type)
			request.predicate = NSPredicate(format: "recordName = %@ and dbid = %@", recordName, dbid)
			do {
				let items = try managedContext.fetch(request)
				for item in items {
					if  let object = item as? ZManagedObject {
						register(object, recordName: recordName, dbID: dbID!)
						objects.append(object)
					}

					if  onlyOne {
						break
					}
				}
			} catch {
				print(error)
			}
		}

		return objects
	}

	func load(type: String, with recordName: String, into dbID: ZDatabaseID?, onlyOne: Bool = true) -> [ZManagedObject] {
		let objects = fetch(type: type, with: recordName, into: dbID, onlyOne: onlyOne)

		invokeUsingDatabaseID(dbID) {
			for object in objects {
				if let zRecord = object as? ZRecord {
					zRecord.convertFromCoreData(into: type, visited: [])
					zRecord.register()
				}
			}
		}

		return objects
	}

	// MARK:- load
	// MARK:-

	func loadContext(into dbID: ZDatabaseID?, onCompletion: AnyClosure?) {
		if  let dbid = dbID?.identifier, gCanLoad {
			deferUntilAvailable(for: .oLoad) {
				var names = [kDestroyName, kLostAndFoundName, kTrashName, kRootName]

				if  dbID == .mineID {
					names.insert(contentsOf: [kRecentsRootName, kFavoritesRootName], at: 0)
				}

				func loadType(_ type: String, onlyNeed: Int? = nil, whenAllAreLoaded: @escaping Closure) {
					let       request = NSFetchRequest<NSFetchRequestResult>(entityName: type)
					request.predicate = NSPredicate(format: "dbid = %@", dbid)
					self.load(type: type, into: dbID, onlyNeed: nil, using: request) { zRecord in
						if  zRecord == nil {          // detect that all needed are loaded
							whenAllAreLoaded()
						}
					}
				}

				for (index, name) in names.enumerated() {
					self.loadZone(with: name, into: dbID) {
						if  index == names.count - 1 { // is last in names
							loadType(kManifestType, onlyNeed: 1) {
								loadType(kFileType) {
									self.makeAvailable()

									onCompletion?(0)
								}
							}
						}
					}
				}
			}
		} else {
			onCompletion?(0)
		}
	}

	func loadZone(with recordName: String, into dbID: ZDatabaseID?, onCompletion: Closure? = nil) {
		let       request = NSFetchRequest<NSFetchRequestResult>(entityName: kZoneType)
		request.predicate = NSPredicate(format: "recordName = %@", recordName)
		let      zRecords = gRemoteStorage.zRecords(for: dbID)

		load(type: kZoneType, into: dbID, onlyNeed: 1, using: request) { (zRecord) -> (Void) in

			// //////////////////////////////////////////////////////////////////////////////// //
			// NOTE: all but the first of multiple values found are duplicates and thus ignored //
			// //////////////////////////////////////////////////////////////////////////////// //

			if  let zone = zRecord as? Zone {
				FOREGROUND {
					zone.respectOrder()

					switch recordName {
						case          kRootName: zRecords?.rootZone         = zone
						case         kTrashName: zRecords?.trashZone        = zone
						case       kDestroyName: zRecords?.destroyZone      = zone
						case   kRecentsRootName: zRecords?.recentsZone      = zone
						case kFavoritesRootName: zRecords?.favoritesZone    = zone
						case  kLostAndFoundName: zRecords?.lostAndFoundZone = zone
						default:                 break
					}

					onCompletion?()
				}
			} else {
				onCompletion?()
			}
		}
	}

	func load(type: String, into dbID: ZDatabaseID?, onlyNeed: Int? = nil, using request: NSFetchRequest<NSFetchRequestResult>, onCompletion: ZRecordClosure? = nil) {
		do {
			let items        = try managedContext.fetch(request)
			if  items.count == 0 {
				onCompletion?(nil)
			} else {
				var            count   = onlyNeed ?? items.count
				for item in items {
					let      zRecord   = item as! ZRecord
					if  let     dbid   = dbID?.identifier,
						zRecord.dbid  == dbid {
						count         -= 1

						FOREGROUND(canBeDirect: true) {
							self.invokeUsingDatabaseID(dbID) {
								zRecord.convertFromCoreData(into: type, visited: [])
								zRecord.register()
								onCompletion?(zRecord)
							}
						}

						if  count == 0 {
							break
						}
					}
				}

				FOREGROUND() {         // not direct: wait until next run loop cycle, so that this loop finishes processing what was loaded
					onCompletion?(nil)
				}
			}
		} catch {
			print(error)
			onCompletion?(nil)
		}
	}

	// MARK:- missing
	// MARK:-

	func loadAllProgeny(for dbID: ZDatabaseID?, onCompletion: Closure? = nil) {
		if  gCanLoad,
			let  records = gRemoteStorage.zRecords(for: dbID!) {
			deferUntilAvailable(for: .oProgeny) {
				let    zones = records.allZones
				var acquired = [String]()

				func loadAllTraits() {
					self.loadTraits(ownedBy: gRemoteStorage.allProgeny, into: dbID) {
						self.makeAvailable()

						gNeedsRecount = true // trigger recount on next timer fire
						onCompletion?()
					}
				}

				func load(childrenOf parents: ZoneArray) {
					acquired.appendUnique(contentsOf: parents.recordNames)
					self.loadChildren(of: parents, into: dbID, acquired) { children in
						if  children.count > 0 {
							load(childrenOf: children)    // get the rest recursively
						} else {
							FOREGROUND(canBeDirect: true) {
								records.applyToAllProgeny { iChild in
									iChild.updateFromCoreDataTraitRelationships()
									iChild.respectOrder()
								}

								loadAllTraits()           // if this is the end of the fetch
							}
						}
					}
				}

				if  zones.count > 0 {
					load(childrenOf: zones)
				} else {
					loadAllTraits()                           // if this is the end of the fetch
				}
			}
		} else {
			onCompletion?()
		}
	}

	func loadTraits(ownedBy zones: ZoneArray, into dbID: ZDatabaseID?, onCompletion: Closure? = nil) {
		let       request = NSFetchRequest<NSFetchRequestResult>(entityName: kTraitType)
		let   recordNames = zones.recordNames
		request.predicate = NSPredicate(format: "ownerRID IN %@", recordNames)

		load(type: kTraitType, into: dbID, using: request) { zRecord in
			if  let trait = zRecord as? ZTrait {
				trait.adopt()
			} else if zRecord == nil {
				onCompletion?()
			}
		}
	}

	func loadChildren(of zones: ZoneArray, into dbID: ZDatabaseID?, _ acquired: [String], onCompletion: ZonesClosure? = nil) {
		var     retrieved = ZoneArray()
		var  totalAquired = acquired
		let       request = NSFetchRequest<NSFetchRequestResult>(entityName: kZoneType)
		request.predicate = NSPredicate(format: "parentRID IN %@", zones.recordNames)

		printDebug(.dData, "loading children from CD for \(zones.count)")

		load(type: kZoneType, into: dbID, using: request) { zRecord in
			if  let zone = zRecord as? Zone,
				let name = zone.recordName,
				totalAquired.contains(name) == false {
				totalAquired.append  (name)
				retrieved.append(zone)
				zone.adopt()
			} else if zRecord == nil {
				printDebug(.dData, "retrieved \(retrieved.count)")
				onCompletion?(retrieved)
			}
		}
	}

	// MARK:- internals
	// MARK:-

	func persistentStore(for url: URL) -> NSPersistentStore? {
		return persistentContainer.persistentStoreCoordinator.persistentStore(for: url)
	}

	func persistentStore(for databaseID: ZDatabaseID?) -> NSPersistentStore? {
		if  let dbid = databaseID {
			switch dbid {
				case .everyoneID: return  publicStore
				default:          return privateStore
			}
		}

		return nil
	}

	lazy var localDescription: NSPersistentStoreDescription = {
		let           desc = NSPersistentStoreDescription(url: localURL)
		desc.configuration = "Local"

		return desc
	}()

	lazy var privateDescription: NSPersistentStoreDescription = {
		let                          desc = NSPersistentStoreDescription(url: privateURL)
		desc.configuration                = "Cloud"
		if  gUseCloudKit {
			let                   options = NSPersistentCloudKitContainerOptions(containerIdentifier: kCloudID)
			desc.cloudKitContainerOptions = options
		}

		return desc
	}()

	lazy var publicDescription: NSPersistentStoreDescription = {
		let                          desc = NSPersistentStoreDescription(url: publicURL)
		desc.configuration                = "Cloud"
		if  gUseCloudKit {
			let                   options = NSPersistentCloudKitContainerOptions(containerIdentifier: kCloudID)
			options.databaseScope         = CKDatabase.Scope.public // default is private
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
		
		container.viewContext.mergePolicy                          = NSMergePolicy(merge: .overwriteMergePolicyType)
		container.viewContext.automaticallyMergesChangesFromParent = true

		return container
	}()

	// MARK:- core data prefers one operation at a time
	// MARK:-

	func isAvailable(for opID: ZCDOperationID) -> Bool { return currentOpID == nil || currentOpID == opID }
	func makeAvailable()                               {        currentOpID  = nil }

	func invokeDeferralMaybe(_ iTimer: Timer?) {
		if  currentOpID == nil {           // nil means core data is no longer doing anything
			if  deferralStack.count == 0 { // check if anything is deferred
				iTimer?.invalidate()       // do not fire again, closure is only invoked once
			} else {
				let waiting = deferralStack.remove(at: 0)
				currentOpID = waiting.opID

				gSignal([.sData])          // tell data detail view about it
				waiting.closure?()         // do what was deferred
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

	// MARK:- internal
	// MARK:-

	func predicate(entityName: String, recordName: String?, databaseID: ZDatabaseID?) -> NSPredicate? {
		if  let          name = recordName,
			let    identifier = databaseID?.identifier {
			let namePredicate = NSPredicate(format: "recordName = %@", name)
			let dbidPredicate = NSPredicate(format: "dbid = %@", identifier)

			if  entityName == kUserEntityName {
				return namePredicate
			}

			return NSCompoundPredicate(andPredicateWithSubpredicates: [namePredicate, dbidPredicate])
		}

		return nil
	}

	func hasExisting(entityName: String, recordName: String?, databaseID: ZDatabaseID?) -> Any? {
		if  isAvailable(for: .oFetch),         // avoid crash due to core data fetch array being simultaneously mutated and enumerated
			let     predicate = predicate(entityName: entityName, recordName: recordName, databaseID: databaseID) {
			let       request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
			request.predicate = predicate

			do {
				let     items = try managedContext.fetch(request)
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
			for updated in self.managedContext.updatedObjects {
				if  let  zone  = updated as? Zone,
					let zdbid  = zone.dbid,
					let pdbid  = zone.parentZone?.dbid {
					if  zdbid != pdbid {
						print(zone)
					}
				}
			}
		}
	}

	// MARK:- existence closures
	// MARK:-

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
			let       request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
			request.predicate = array.predicate(entityName)
			let         count = "\(array.count)".appendingSpacesToLength(6)

			printDebug(.dExist, "\(dbID.identifier) = \(count)\(entityName)")

			deferUntilAvailable(for: .oExistence) {
				FOREGROUND {
					do {
						let items = try self.managedContext.fetch(request)
						for item in items {
							if  let zRecord = item as? ZRecord {           // insert zrecord into closures
								array.updateClosureForZRecord(zRecord, of: entityName)
								zRecord.needAdoption()
							}
						}
					} catch {

					}

					array.fireClosures()
					self.setClosures([], for: entityName, dbID: dbID)
					self.makeAvailable()
					onCompletion?(0)
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

				self.processClosures(for: entityName, dbID: dbID) { value in
					processForEntityName(at: index - 1)                // recursive while loop
				}
			}
		}

		processForEntityName(at: firstIndex)
	}

	func existsForEntityNameAsync(_ entityName: String, dbID: ZDatabaseID?, entity: ZEntityDescriptor?, file: ZFileDescriptor?, onExistence: @escaping ZRecordClosure) {
		if  let  dbid = dbID {
			var array = closures(for: entityName, dbID: dbid) // creates dict and array

			array.append(ZExistence(closure: onExistence, entity: entity, file: file))
			setClosures(array, for: entityName, dbID: dbid)
		}
	}

	func zRecordExistsAsync(for descriptor: ZEntityDescriptor, onExistence: @escaping ZRecordClosure) {
		existsForEntityNameAsync(descriptor.entityName, dbID: descriptor.databaseID, entity: descriptor, file: nil, onExistence: onExistence)
	}

	func fileExistsAsync(for descriptor: ZFileDescriptor?, dbID: ZDatabaseID?, onExistence: @escaping ZRecordClosure) {
		existsForEntityNameAsync(kFileType, dbID: dbID, entity: nil, file: descriptor, onExistence: onExistence)
	}

	// MARK:- search
	// MARK:-

	func search(for match: String, within dbID: ZDatabaseID?, onCompletion: ZRecordsClosure? = nil) {
		if  gIsReadyToShowUI, gCanLoad,
			let        dbid = dbID?.identifier {
			let  searchable = match.searchable
			let idPredicate = NSPredicate(format: "zoneName like %@", searchable)
			for type in [kZoneType] { //, kTraitType] {
				self.search(within: dbid, type: type, using: idPredicate) { matches in
					onCompletion?(matches)
				}
			}
		} else {
			onCompletion?([])
		}
	}

	func search(within dbid: String, type: String, using predicate: NSPredicate, uniqueOnly: Bool = true, onCompletion: ZRecordsClosure? = nil) {
		var result = ZRecordsArray()

		if !gCanLoad || !gIsReadyToShowUI {
			onCompletion?(result)
		} else {
			let   dbPredicate = NSPredicate(format: "dbid = %@", dbid)
			let       request = NSFetchRequest<NSFetchRequestResult>(entityName: type)
			request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, dbPredicate])

			deferUntilAvailable(for: .oSearch) {
				do {
					let items = try self.managedContext.fetch(request)
					for item in items {
						if  let zRecord = item as? ZRecord {
							if  uniqueOnly {
								result.appendUnique(item: zRecord)
							} else {
								result.append(zRecord)
							}
						}
					}
				} catch {
					print("search fetch failed")
				}

				self.makeAvailable() // before calling closure

				onCompletion?(result)
			}
		}
	}

	// MARK:- vaccuum
	// MARK:-

	func emptyZones(within dbID: ZDatabaseID?, onCompletion: ZRecordsClosure? = nil) {
		if  let      dbid = dbID?.identifier {
			let predicate = NSPredicate(format: "zoneName = NULL")
			search(within: dbid, type: kZoneType, using: predicate) { matches in
				onCompletion?(matches)
			}
		}
	}

	func removeAllDuplicateZones(in dbID: ZDatabaseID?) {
		if  let          dbid = dbID?.identifier {
			let       request = NSFetchRequest<NSFetchRequestResult>(entityName: kZoneType)
			request.predicate = NSPredicate(format: "dbid = %@", dbid)

			load(type: kZoneType, into: dbID, using: request) { zRecord in }
		}
	}

	func removeAllDuplicates(of zRecord: ZRecord) {
		if  let      dbid = zRecord.databaseID?.identifier,
			let  ckRecord = zRecord.ckRecord {
			let      name = ckRecord.recordID.recordName
			let predicate = NSPredicate(format: "recordName = %@", name)

			search(within: dbid, type: kZoneType, using: predicate) { zRecords in
				let  count = zRecords.count
				let extras = zRecords.filter() { $0 != ckRecord }

				if  count > extras.count {
					FOREGROUND {
						for extra in extras {
							self.managedContext.delete(extra)
						}
					}
				}
			}
		}
	}

}
