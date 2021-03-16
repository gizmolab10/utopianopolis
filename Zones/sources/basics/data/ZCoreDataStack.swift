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
let  gCoreDataURL    : URL = { return gDataURL.appendingPathComponent("data") }()
let  gDataURL        : URL = {
	return try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
		.appendingPathComponent("Seriously", isDirectory: true)
}()

class ZCoreDataStack: NSObject {

	let          cloudKitID = "iCloud.com.seriously.CoreData"
	let            localURL = gCoreDataURL.appendingPathComponent("local.store")
	let           publicURL = gCoreDataURL.appendingPathComponent("cloud.public.store")
	let          privateURL = gCoreDataURL.appendingPathComponent("cloud.private.store")
	lazy var          model : NSManagedObjectModel          = { return NSManagedObjectModel.mergedModel(from: nil)! }()
	lazy var    coordinator : NSPersistentStoreCoordinator? = { return persistentContainer.persistentStoreCoordinator }()
	lazy var managedContext : NSManagedObjectContext        = { return persistentContainer.viewContext }()
	lazy var   privateStore : NSPersistentStore?            = { return persistentStore(for: privateURL) }()
	lazy var    publicStore : NSPersistentStore?            = { return persistentStore(for: publicURL) }()
	lazy var     localStore : NSPersistentStore?            = { return persistentStore(for: localURL) }()
	var            isDoneOp : Bool                            { return currentOpID == nil }
	var          statusText : String                          { return statusOpID?.description ?? "" }
	var          statusOpID : ZCDOperationID?                 { return currentOpID ?? waitingOpID}
	var         waitingOpID : ZCDOperationID?
	var         currentOpID : ZCDOperationID?
	var availabilityClosure : Closure?

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
			let                   options = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitID)
			desc.cloudKitContainerOptions = options
		}

		return desc
	}()

	lazy var publicDescription: NSPersistentStoreDescription = {
		let                          desc = NSPersistentStoreDescription(url: publicURL)
		desc.configuration                = "Cloud"
		if  gUseCloudKit {
			let                   options = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitID)
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

		container.viewContext.mergePolicy                          = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
		container.viewContext.automaticallyMergesChangesFromParent = true

		return container
	}()

	// MARK:- internal
	// MARK:-

	func availabilityFire(_ iTimer: Timer?) {
		if  currentOpID == nil {
			currentOpID  = waitingOpID
			waitingOpID  = nil

			iTimer?.invalidate()
			gSignal([.sData])
			availabilityClosure?()
		}
	}

	func deferUntilAvailable(for opID: ZCDOperationID, _ closure: @escaping Closure) {
		waitingOpID         = opID     // so status text can show it
		availabilityClosure = closure  // for availabilityFire to invoke

		gStartTimer(for: .tCoreDataAvailable)
	}

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
		if  let     predicate = predicate(entityName: entityName, recordName: recordName, databaseID: databaseID) {
			let       request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
			request.predicate = predicate
			do {
				let items = try managedContext.fetch(request)

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

	// MARK:- save
	// MARK:-

	func saveContext() {
		if  gCanSave {
			deferUntilAvailable(for: .oSave) {
				FOREGROUND(canBeDirect: true) {
					let context = self.managedContext

					if  context.hasChanges {
						self.checkCrossStore()
						do {
							try context.save()
						} catch {
							print(error)
						}
					}

					self.currentOpID = nil
				}
			}
		}
	}

	// MARK:- restore
	// MARK:-

	func loadContext(into dbID: ZDatabaseID?, onCompletion: AnyClosure?) {
		if !gCanLoad {
			onCompletion?(0)
		} else {
			deferUntilAvailable(for: .oLoad) {
				var names = [kDestroyName, kLostAndFoundName, kTrashName, kRootName]
				var index = names.count - 1

				if  dbID == .mineID {
					names.insert(contentsOf: [kRecentsRootName, kFavoritesRootName], at: 0)
					index = names.count - 1
				}

				func loadFullContext() {
					let name = names[index]

					self.loadZone(with: name, into: dbID) {
						onCompletion?(0)

						index -= 1

						if  index >= 0 {
							loadFullContext()
						} else {
							self.load(type: kManifestType, into: dbID, onlyNeed: 1, using: NSFetchRequest<NSFetchRequestResult>(entityName: kManifestType)) { zRecord in
								if  zRecord == nil {
									self.currentOpID = nil
//									gRemoteStorage.recount()

									onCompletion?(0)
								}
							}
						}
					}
				}

				BACKGROUND(canBeDirect: true) {
					loadFullContext()
				}
			}
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

				FOREGROUND() { // wait until next run loop cycle
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
					BACKGROUND(canBeDirect: true) {
						self.loadTraits(ownedBy: gRemoteStorage.allProgeny, into: dbID) {
							self.currentOpID = nil

							gRemoteStorage.recount()
							onCompletion?()
						}
					}
				}

				func load(childrenOf parents: ZoneArray) {
					acquired.appendUnique(contentsOf: parents.recordNames)
					BACKGROUND(canBeDirect: true) {
						self.loadChildren(of: parents, into: dbID, acquired) { children in
							if  children.count > 0 {
								load(childrenOf: children) // recurse
							} else {
								FOREGROUND(canBeDirect: true) {
									records.applyToAllProgeny { iChild in
										iChild.updateFromCoreDataTraitRelationships()
										iChild.respectOrder()
									}

									loadAllTraits()
								}
							}
						}
					}
				}

				if  zones.count == 0 {
					loadAllTraits()
				} else {
					load(childrenOf: zones)
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

	// MARK:- search
	// MARK:-

	func search(for match: String, within dbID: ZDatabaseID?, onCompletion: ZRecordsClosure? = nil) {
		if  gIsReadyToShowUI,
			let        dbid = dbID?.identifier {
			let  searchable = match.searchable
			let idPredicate = NSPredicate(format: "zoneName like %@", searchable)
			for type in [kZoneType] { //, kTraitType] {
				self.search(within: dbid, type: type, using: idPredicate) { matches in
					onCompletion?(matches)
				}
			}
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

			self.deferUntilAvailable(for: .oSearch) {
				BACKGROUND(canBeDirect: true) {
					do {
						let items = try self.managedContext.fetch(request)
						for item in items {
							if  let zRecord = item as? ZRecord {
								if  uniqueOnly {
									result.appendUnique(zRecord)
								} else {
									result.append(zRecord)
								}
							}
						}
					} catch {
						print("search fetch failed")
					}

					self.currentOpID = nil // before calling closure

					onCompletion?(result)
				}
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
