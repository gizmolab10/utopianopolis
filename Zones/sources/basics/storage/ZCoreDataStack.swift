//
//  ZCoreDataStack.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/3/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

func gLoadContext(into dbID: ZDatabaseID, onCompletion: AnyClosure? = nil) { gCoreDataStack.loadContext(into: dbID, onCompletion: onCompletion) }
func gSaveContext()                                                        { gCoreDataStack.saveContext() }
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
	let databaseID : ZDatabaseID
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
	var   missingRegistry = [ZDatabaseID : [String]]()
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

	// MARK:- load
	// MARK:-

	func loadContext(into dbID: ZDatabaseID, onCompletion: AnyClosure?) {
		if  gCanLoad {
			deferUntilAvailable(for: .oLoad) {
				var names = [kRootName, kTrashName, kDestroyName, kLostAndFoundName]

				if  dbID == .mineID {
					names.insert(contentsOf: [kRecentsRootName, kFavoritesRootName], at: 1)
				}

				for name in names {
					self.loadZone(recordName: name, into: dbID)
				}

				self.load(type: kManifestType, into: dbID, onlyOne: false)
				self.load(type: kFileType,     into: dbID, onlyOne: false)
				gRemoteStorage.updateManifestCount(for: dbID)
				self.makeAvailable()

				onCompletion?(0)
			}
		} else {
			onCompletion?(0)
		}
	}

	func loadZone(recordName: String, into dbID: ZDatabaseID) {
		if  let zRecords = gRemoteStorage.zRecords(for: dbID) {
			let  fetched = load(type: kZoneType, recordName: recordName, into: dbID)

			for zRecord in fetched {
				if  let zone = zRecord as? Zone {
					zone.respectOrder()

					switch recordName {
						case          kRootName: zRecords.rootZone         = zone
						case         kTrashName: zRecords.trashZone        = zone
						case       kDestroyName: zRecords.destroyZone      = zone
						case   kRecentsRootName: zRecords.recentsZone      = zone
						case kFavoritesRootName: zRecords.favoritesZone    = zone
						case  kLostAndFoundName: zRecords.lostAndFoundZone = zone
						default:                 break
					}
				}
			}
		}
	}

	// called by load recordName and find type, recordName
	// fetch, extract data, register

	@discardableResult func load(type: String, recordName: String = "", into dbID: ZDatabaseID, onlyOne: Bool = true) -> [ZManagedObject] {
		let objects = fetch(type: type, recordName: recordName, into: dbID, onlyOne: onlyOne)

		invokeUsingDatabaseID(dbID) {
			for object in objects {
				if let zRecord = object as? ZRecord {
					zRecord.convertFromCoreData(visited: [])
					zRecord.register()
				}
			}
		}

		return objects
	}

	// MARK:- registry
	// MARK:-

	func registerObject(_ object: ZManagedObject, recordName: String, dbID: ZDatabaseID) {
		var dict  = fetchedRegistry[dbID]
		if  dict == nil {
			dict  = [String : ZManagedObject]()
		}

		dict?[recordName]     = object
		fetchedRegistry[dbID] = dict

		(object as? ZRecord)?.register() // for records read from file 
	}

	func missingFrom(_ dbID: ZDatabaseID) -> [String] {
		var missing  = missingRegistry[dbID]
		if  missing == nil {
			missing  = [String]()
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

	func lookup(recordName: String, into dbID: ZDatabaseID, onlyOne: Bool = true) -> ZManagedObject? {
		if  let    object = fetchedRegistry[dbID]?[recordName] {
			return object
		}

		return nil
	}

	func resolveMissing(from dbID: ZDatabaseID) {
		var missing         = missingFrom(dbID)
		for name in missing {
			let found       = find(type: kZoneType, recordName: name, into: dbID, trackMissing: false)
			if  found.count > 0,
				let   index = missing.firstIndex(of: name) {
				missing.remove(at: index)
			}
		}

		missingRegistry[dbID] = missing
	}

	func find(type: String, recordName: String, into dbID: ZDatabaseID, onlyOne: Bool = true, trackMissing: Bool = true) -> [ZManagedObject] {
		let           dbid = dbID == .everyoneID ? dbID : .mineID
		if  let     object = lookup(recordName: recordName, into: dbid) {
			return [object]
		}

		if  trackMissing, missingFrom(dbid).contains(recordName) {
			return []
		}

		return fetch(type: type, recordName: recordName, into: dbid, onlyOne: onlyOne)
	}

	func dbidPredicate(from dbid: String) -> NSPredicate {
		return NSPredicate(format: "dbid = %@", dbid)
	}

	func fetchUsing(request: NSFetchRequest<NSFetchRequestResult>, type: String, onlyOne: Bool = true) -> [ZManagedObject] {
		var   objects = [ZManagedObject]()
		do {
			let items = try managedContext.fetch(request)
			for item in items {
				if  let object = item as? ZManagedObject {
					objects.append(object)
				}

				if  onlyOne {

					// //////////////////////////////////////////////////////////////////////////////// //
					// NOTE: all but the first of multiple values found are duplicates and thus ignored //
					// //////////////////////////////////////////////////////////////////////////////// //

					break
				}
			}
		} catch {
			print(error)
		}

		return objects
	}

	// must call this on foreground thread
	// else throws mutate while enumerate error

	func fetch(type: String, recordName: String = "", into dbID: ZDatabaseID, onlyOne: Bool = true) -> [ZManagedObject] {
		var       objects = [ZManagedObject]()
		let          dbid = dbID.identifier
		let       request = NSFetchRequest<NSFetchRequestResult>(entityName: type)
		let             r = NSPredicate(format: "recordName = %@", recordName)
		let             d = dbidPredicate(from: dbid)
		request.predicate = !onlyOne ? d : type == kUserType ? r : r.add(d)
		let     items     = fetchUsing(request: request, type: type, onlyOne: onlyOne)
		if  items.count  == 0 {
			registerAsMissing(recordName: recordName, dbID: dbID)
		} else {
			for item in items {
				registerObject(item, recordName: recordName, dbID: dbID)
				objects.append(item)
			}
		}


		return objects
	}

	// MARK:- search
	// MARK:-

	func searchZonesForName(_ name: String, within dbID: ZDatabaseID, onCompletion: ZRecordsClosure? = nil) {
		if  gIsReadyToShowUI, gCanLoad {
			let        dbid = dbID.identifier
			let  searchable = name.searchable
			let idPredicate = NSPredicate(format: "zoneName contains[cd] %@", searchable)
			for entityName in [kZoneType] { // kTraitType
				self.search(within: dbid, entityName: entityName, using: idPredicate) { matches in
					onCompletion?(matches)
				}
			}
		} else {
			onCompletion?([])
		}
	}

	func searchZonesForNames(_ names: [String], within dbID: ZDatabaseID, onCompletion: StringZRecordsDictionaryClosure? = nil) {
		var            result = StringZRecordsDictionary()
		if  gIsReadyToShowUI, gCanLoad {
			let          dbid = dbID.identifier
			let   searchables = names.map { $0.searchable }
			var         count = searchables.count

			for searchable in searchables {
				let predicate = NSPredicate(format: "zoneName contains[cd] %@", searchable)

				for entityName in [kZoneType] { // kTraitType
					self.search(within: dbid, entityName: entityName, using: predicate) { matches in
						result[searchable] = matches
						count             -= 1
						if  count         == 0 {
							onCompletion?(result)
						}
					}
				}
			}
		} else {
			onCompletion?(result)
		}
	}

	func search(within dbid: String, entityName: String, using predicate: NSPredicate, onCompletion: ZRecordsClosure? = nil) {
		var result = ZRecordsArray()

		if !gCanLoad || !gIsReadyToShowUI {
			onCompletion?(result)
		} else {
			let       request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
			request.predicate = predicate.add(dbidPredicate(from: dbid))

			deferUntilAvailable(for: .oSearch) {
				do {
					let items = try self.managedContext.fetch(request)
					for item in items {
						if  let zRecord = item as? ZRecord {
							result.append(zRecord)
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

	// MARK:- missing
	// MARK:-

	func loadAllProgeny(for dbID: ZDatabaseID, onCompletion: Closure? = nil) {
		if  gCanLoad,
			let  records = gRemoteStorage.zRecords(for: dbID) {
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

	func loadTraits(ownedBy zones: ZoneArray, into dbID: ZDatabaseID, onCompletion: Closure? = nil) {
		let       request = NSFetchRequest<NSFetchRequestResult>(entityName: kTraitType)
		let   recordNames = zones.recordNames
		request.predicate = NSPredicate(format: "ownerRID IN %@", recordNames)
		let       fetched = fetchUsing(request: request, type: kTraitType)

		for zRecord in fetched {
			if  let trait = zRecord as? ZTrait {
				trait.adopt()
			}
		}

		onCompletion?()
	}

	func loadChildren(of zones: ZoneArray, into dbID: ZDatabaseID, _ acquired: [String], onCompletion: ZonesClosure? = nil) {
		var     retrieved = ZoneArray()
		var  totalAquired = acquired
		let       request = NSFetchRequest<NSFetchRequestResult>(entityName: kZoneType)
		request.predicate = NSPredicate(format: "parentRID IN %@", zones.recordNames)
		let       fetched = fetchUsing(request: request, type: kZoneType)

		printDebug(.dData, "loading children from CD for \(zones.count)")

		for zRecord in fetched {
			if  let zone = zRecord as? Zone,
				let name = zone.recordName,
				totalAquired.contains(name) == false {
				totalAquired.append  (name)
				retrieved.append(zone)
				zone.adopt()
			}
		}

		printDebug(.dData, "retrieved \(retrieved.count)")
		onCompletion?(retrieved)
	}

	// MARK:- internals
	// MARK:-

	func persistentStore(for url: URL) -> NSPersistentStore? {
		return persistentContainer.persistentStoreCoordinator.persistentStore(for: url)
	}

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

				gSignal([.sStatus])          // tell data detail view about it
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

	func predicate(entityName: String, recordName: String?, databaseID: ZDatabaseID) -> NSPredicate? {
		if  let          name = recordName {
			let    identifier = databaseID.identifier
			let namePredicate = NSPredicate(format: "recordName = %@", name)
			let dbidPredicate = NSPredicate(format: "dbid = %@", identifier)

			if  entityName == kUserEntityName {
				return namePredicate
			}

			return NSCompoundPredicate(andPredicateWithSubpredicates: [namePredicate, dbidPredicate])
		}

		return nil
	}

	func hasExisting(entityName: String, recordName: String?, databaseID: ZDatabaseID) -> Any? {
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

	func existsForEntityNameAsync(_ entityName: String, dbID: ZDatabaseID, entity: ZEntityDescriptor?, file: ZFileDescriptor?, onExistence: @escaping ZRecordClosure) {
		var array = closures(for: entityName, dbID: dbID) // creates dict and array

		array.append(ZExistence(closure: onExistence, entity: entity, file: file))
		setClosures(array, for: entityName, dbID: dbID)
	}

	func zRecordExistsAsync(for descriptor: ZEntityDescriptor, onExistence: @escaping ZRecordClosure) {
		existsForEntityNameAsync(descriptor.entityName, dbID: descriptor.databaseID, entity: descriptor, file: nil, onExistence: onExistence)
	}

	func fileExistsAsync(for descriptor: ZFileDescriptor?, dbID: ZDatabaseID, onExistence: @escaping ZRecordClosure) {
		existsForEntityNameAsync(kFileType, dbID: dbID, entity: nil, file: descriptor, onExistence: onExistence)
	}

	// MARK:- vaccuum
	// MARK:-

	func emptyZones(within dbID: ZDatabaseID, onCompletion: ZRecordsClosure? = nil) {
		let      dbid = dbID.identifier
		let predicate = NSPredicate(format: "zoneName = NULL")
		search(within: dbid, entityName: kZoneType, using: predicate) { matches in
			onCompletion?(matches)
		}
	}

	func removeAllDuplicatesOf(_ zRecord: ZRecord) {
		if  let      dbid = zRecord.dbid,
			let      name = zRecord.recordName {
			let predicate = NSPredicate(format: "recordName = %@", name)

			search(within: dbid, entityName: kZoneType, using: predicate) { zRecords in
				let  count = zRecords.count
				let extras = zRecords.filter() { $0 != zRecord }

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
