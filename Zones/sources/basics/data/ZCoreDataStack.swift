//
//  ZCoreDataStack.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/3/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

let gCoreDataStack = ZCoreDataStack()
var gCoreDataURL   : URL = { return gDataURL.appendingPathComponent("data") }()
var gDataURL       : URL = {
	return try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
		.appendingPathComponent("Seriously", isDirectory: true)
}()
func gLoadContext(into dbID: ZDatabaseID?, onCompletion: AnyClosure? = nil) { gCoreDataStack.loadContext(into: dbID, onCompletion: onCompletion) }
func gSaveContext()                                                         { gCoreDataStack.saveContext() }

class ZCoreDataStack: NSObject {

	let             cloudID = "iCloud.com.seriously.CoreData"
	let            localURL = gCoreDataURL.appendingPathComponent("local.store")
	let           publicURL = gCoreDataURL.appendingPathComponent("cloud.public.store")
	let          privateURL = gCoreDataURL.appendingPathComponent("cloud.private.store")
	lazy var          model : NSManagedObjectModel          = { return NSManagedObjectModel.mergedModel(from: nil)! }()
	lazy var    coordinator : NSPersistentStoreCoordinator? = { return persistentContainer.persistentStoreCoordinator }()
	lazy var managedContext : NSManagedObjectContext        = { return persistentContainer.viewContext }()
	var        privateStore : NSPersistentStore? { return persistentStore(for: privateURL) }
	var         publicStore : NSPersistentStore? { return persistentStore(for: publicURL) }
	var          localStore : NSPersistentStore? { return persistentStore(for: localURL) }
	var       lastConverted = [String : [String]]()

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
		let                   options = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudID)
		let                      desc = NSPersistentStoreDescription(url: privateURL)
		desc.configuration            = "Cloud"
		desc.cloudKitContainerOptions = options

		return desc
	}()

	lazy var publicDescription: NSPersistentStoreDescription = {
		let                   options = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudID)
		let                      desc = NSPersistentStoreDescription(url: publicURL)
		desc.configuration            = "Cloud"
		options.databaseScope         = CKDatabase.Scope.public // default is private
		desc.cloudKitContainerOptions = options

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

	// MARK:- save
	// MARK:-

	func saveContext() {
		if  gUseCoreData,
			managedContext.hasChanges {
			do {
				try managedContext.save()
			} catch {
				print(error)
			}
		}
	}

	// MARK:- restore
	// MARK:-

	func loadContext(into dbID: ZDatabaseID?, onCompletion: AnyClosure?) {
		if  gUseCoreData {
			var names = [kRootName, kDestroyName, kTrashName, kLostAndFoundName]

			if  dbID == .mineID {
				names.append(contentsOf: [kRecentsRootName, kFavoritesRootName])
			}

			gTimers.resetTimer(for: .tLoadCoreData, withTimeInterval: 1.0, repeats: true) { iTimer in gUpdateStartupProgress() }

			BACKGROUND {
				for name in names {
					self.loadZone(with: name, into: dbID)
				}

				self.load(type: kManifestType, into: dbID, using: NSFetchRequest<NSFetchRequestResult>(entityName: kManifestType))

				gTimers.stopTimer(for: .tLoadCoreData)
			}

			onCompletion?(0)
		}
	}

	func loadAllProgeny(for dbID: ZDatabaseID?, onCompletion: Closure? = nil) {
		if  let  records = gRemoteStorage.zRecords(for: dbID!) {
			let zRecords = ZRecordsArray(records.zRecordsLookup.values).filter { $0 is Zone }

			func load(_ zones: ZoneArray) {
				loadChildren(of: zones, into: dbID) { children in
					if  children.count > 0 {
						load(children) // recurse
					} else {
						FOREGROUND {
							records.rootZone?.traverseAllProgeny { iChild in
								iChild.updateFromCoreDataTraitRelationships(visited: [])
								iChild.respectOrder()
							}

							let allRecords = ZRecordsArray(records.zRecordsLookup.values).filter { $0 is Zone }
							let   allZones = allRecords.map { zRecord -> Zone in
								return zRecord as! Zone
							}

							BACKGROUND {
								self.loadTraits(ownedBy: allZones, into: dbID, onCompletion: onCompletion)
							}
						}
					}
				}
			}

			if  zRecords.count > 0 {
				BACKGROUND {
					let zones = zRecords.map { zRecord -> Zone in
						return zRecord as! Zone
					}

					load(zones)
				}
			}
		}
	}

	func loadTraits(ownedBy zones: ZoneArray, into dbID: ZDatabaseID?, onCompletion: Closure? = nil) {
		let       request = NSFetchRequest<NSFetchRequestResult>(entityName: kTraitType)
		let   recordNames = zones.recordNames
		request.predicate = NSPredicate(format: "ownerRID IN %@", recordNames)

		load(type: kTraitType, into: dbID, using: request) { zRecords in
			for zRecord in zRecords {
				if  let trait = zRecord as? ZTrait {
					trait.adopt()
				}
			}

			onCompletion?()
		}
	}

	func loadChildren(of zones: ZoneArray, into dbID: ZDatabaseID?, onCompletion: ZonesClosure? = nil) {
		var     retrieved = ZoneArray()
		let       request = NSFetchRequest<NSFetchRequestResult>(entityName: kZoneType)
		let   recordNames = zones.recordNames
		request.predicate = NSPredicate(format: "parentRID IN %@", recordNames)

		load(type: kZoneType, into: dbID, using: request) { zRecords in
			for zRecord in zRecords {
				if  let zone = zRecord as? Zone, !zones.containsMatch(to: zone) {
					retrieved.append(zone)
					zone.adopt()
				}
			}

			onCompletion?(retrieved)
		}
	}

	func loadZone(with recordName: String, into dbID: ZDatabaseID?) {
		let       request = NSFetchRequest<NSFetchRequestResult>(entityName: kZoneType)
		request.predicate = NSPredicate(format: "recordName = \"\(recordName)\"")

		load(type: kZoneType, into: dbID, using: request, onlyNeed: 1) { (zRecords) -> (Void) in

			// //////////////////////////////////////////////////////////////////////////////// //
			// NOTE: all but the first of multiple values found are duplicates and thus ignored //
			// //////////////////////////////////////////////////////////////////////////////// //

			if  zRecords.count > 0,
				let       zone = zRecords[0] as? Zone,
				let      cloud = gRemoteStorage.zRecords(for: dbID) {

				FOREGROUND {
					zone.traverseAllProgeny { iChild in
						iChild.updateFromCoreDataTraitRelationships(visited: [])
						iChild.respectOrder()
					}

					switch recordName {
						case          kRootName: cloud.rootZone         = zone
						case         kTrashName: cloud.trashZone        = zone
						case       kDestroyName: cloud.destroyZone      = zone
						case   kRecentsRootName: cloud.recentsZone      = zone
						case kFavoritesRootName: cloud.favoritesZone    = zone
						case  kLostAndFoundName: cloud.lostAndFoundZone = zone
						default: break
					}
				}
			}
		}
	}

	func load(type: String, into dbID: ZDatabaseID?, using request: NSFetchRequest<NSFetchRequestResult>, onlyNeed: Int? = nil, onCompletion: ZRecordsClosure? = nil) {
		var          records = ZRecordsArray()
		do {
			let items        = try managedContext.fetch(request)
			if  items.count == 0 {
				onCompletion?(records)
			} else {
				var              count  = onlyNeed ?? items.count
				for item in items {
					count              -= 1
					let        zRecord  = item as! ZRecord
					if  count           < 0 {
						onCompletion?(records)
					} else if let dbid  = dbID?.identifier,
						zRecord.dbid   == dbid {
						records.append(zRecord)

						FOREGROUND {
							var converted = zRecord.convertFromCoreData(into: type, visited: self.lastConverted[dbid])

							zRecord.register()

							if  type == kZoneType {
								converted.appendUnique(contentsOf: self.lastConverted[dbid] ?? [])

								self.lastConverted[dbid] = converted
							}
						}
					}
				}
			}
		} catch {
			print(error)
			onCompletion?(records)
		}
	}

	@discardableResult
	func convertZoneFromCoreData(_ record: ZRecord, into dbID: ZDatabaseID?) -> [String] {
		var converted = [String]()

		if  let  dbid = dbID?.identifier {
			converted = record.convertFromCoreData(into: kZoneType, visited: lastConverted[dbid])

			converted.appendUnique(contentsOf: lastConverted[dbid] ?? [])

			lastConverted[dbid] = converted
		}

		return converted
	}

	// MARK:- search
	// MARK:-

	func search(for match: String, within dbID: ZDatabaseID?) -> ZRecordsArray {
		var result = ZRecordsArray()

		if  gIsReadyToShowUI,
			let        dbid = dbID?.identifier {
			let  searchable = match.searchable
			let idPredicate = NSPredicate(format: "zoneName like \"\(searchable)\"")
			for type in [kZoneType] { //, kTraitType] {
				let matches = search(within: dbid, type: type, using: idPredicate)

				result.appendUnique(contentsOf: matches)
			}
		}

		return result
	}

	func search(within dbid: String, type: String, using predicate: NSPredicate, uniqueOnly: Bool = true) -> ZRecordsArray {
		var        result = ZRecordsArray()
		let       request = NSFetchRequest<NSFetchRequestResult>(entityName: type)
		let   dbPredicate = NSPredicate(format: "dbid = \"\(dbid)\"")
		request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, dbPredicate])

		do {
			let items = try managedContext.fetch(request)

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
			print("oops!")
		}

		return result
	}

	// MARK:- vaccuum
	// MARK:-

	func emptyZones(within dbID: ZDatabaseID?) -> ZRecordsArray {
		var       results = ZRecordsArray()
		if  let      dbid = dbID?.identifier {
			let predicate = NSPredicate(format: "zoneName = NULL")
			results       = search(within: dbid, type: kZoneType, using: predicate)
		}

		return results
	}

	func removeAllDuplicates(of zRecord: ZRecord) {
		if  let      dbid = zRecord.databaseID?.identifier,
			let  ckRecord = zRecord.ckRecord {
			let      name = ckRecord.recordID.recordName
			let predicate = NSPredicate(format: "recordName = \"\(name)\"")
			var     items = search(within: dbid, type: kZoneType, using: predicate)
			let     count = items.count
			items         = items.filter() { $0 != ckRecord }

			if  count > items.count {
				print("\(count)")
			}
		}
	}

}
