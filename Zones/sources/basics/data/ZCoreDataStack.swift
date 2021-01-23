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
func gLoadContext(into dbID: ZDatabaseID?) { gCoreDataStack.loadContext(into: dbID) }
func gSaveContext()                        { gCoreDataStack.saveContext() }

class ZCoreDataStack: NSObject {

	let             cloudID = "iCloud.com.zones.Zones"
	let            localURL = gCoreDataURL.appendingPathComponent("local.store")
	let           publicURL = gCoreDataURL.appendingPathComponent("cloud.public.store")
	let          privateURL = gCoreDataURL.appendingPathComponent("cloud.private.store")
	lazy var          model : NSManagedObjectModel          = { return NSManagedObjectModel.mergedModel(from: nil)! }()
	lazy var    coordinator : NSPersistentStoreCoordinator? = { return persistentContainer.persistentStoreCoordinator }()
	lazy var managedContext : NSManagedObjectContext        = { return persistentContainer.viewContext }()
	var       lastConverted = [String : [String]]()
	var        privateStore : NSPersistentStore? { return persistentStore(for: privateURL) }
	var         publicStore : NSPersistentStore? { return persistentStore(for: publicURL) }
	var          localStore : NSPersistentStore? { return persistentStore(for: localURL) }

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

	lazy var publicDescription: NSPersistentStoreDescription = {
		let        options = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudID)
		let           desc = NSPersistentStoreDescription(url: publicURL)
		desc.configuration = "Cloud"

		if  options.responds(to: Selector(("setDatabaseScope:"))) {
			options.perform(Selector(("setDatabaseScope:")), with: CKDatabase.Scope.public) // default is private
		}

		desc.cloudKitContainerOptions = options

		return desc
	}()

	lazy var privateDescription: NSPersistentStoreDescription = {
		let                   options = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudID)
		let                      desc = NSPersistentStoreDescription(url: privateURL)
		desc.configuration            = "Cloud"
		desc.cloudKitContainerOptions = options

		return desc
	}()

	lazy var persistentContainer: NSPersistentCloudKitContainer = {
		let  container = NSPersistentCloudKitContainer(name: "seriously", managedObjectModel: model)
		let publicDesc = publicDescription

		ValueTransformer.setValueTransformer(  ZReferenceTransformer(), forName:   gReferenceTransformerName)
		ValueTransformer.setValueTransformer( ZAssetArrayTransformer(), forName:  gAssetArrayTransformerName)
		ValueTransformer.setValueTransformer(ZStringArrayTransformer(), forName: gStringArrayTransformerName)

		// Update the container's list of store descriptions
		container.persistentStoreDescriptions = [
			privateDescription,
			localDescription
		]

		if  let options = publicDesc.cloudKitContainerOptions, options.responds(to: Selector(("setDatabaseScope:"))) {
			container.persistentStoreDescriptions.append(publicDesc)
		}

		container.loadPersistentStores() { (storeDescription, iError) in
			if  let error = iError as NSError? {
				fatalError("Unresolved error \(error), \(error.userInfo)")
			}
		}

		container.viewContext.mergePolicy                          = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
		container.viewContext.automaticallyMergesChangesFromParent = true

		return container
	}()

	func saveContext() {
		if  gUseCoreData,
			managedContext.hasChanges {
			do {
				try managedContext.save()
			} catch {
				// Replace this implementation with code to handle the error appropriately.
				// fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
				let nserror = error as NSError
				fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
			}
		}
	}

	func loadContext(into dbID: ZDatabaseID?) {
		if  gUseCoreData {
			FOREGROUND {
				var names = [kRootName, kDestroyName, kTrashName, kLostAndFoundName]

				if  dbID == .mineID {
					names.append(contentsOf: [kRecentsRootName, kFavoritesRootName])
				}

				for name in names {
					self.loadZone(with: name, into: dbID)
				}

				self.load(type: kManifestType, into: dbID, using: NSFetchRequest<NSFetchRequestResult>(entityName: kManifestType))
			}
		}
	}

	func loadZone(with recordName: String, into dbID: ZDatabaseID?) {
		if  let          dbid = dbID?.identifier {
			let       request = NSFetchRequest<NSFetchRequestResult>(entityName: kZoneType)
			let   idPredicate = NSPredicate(format: "recordName = \"\(recordName)\"")
			let   dbPredicate = NSPredicate(format: "dbid = \"\(dbid)\"")
			request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [idPredicate, dbPredicate])
			let      zRecords = load(type: kZoneType, into: dbID, using: request)

			// //////////////////////////////////////////////////////////////////////////////// //
			// NOTE: all but the first of multiple values found are duplicates and thus ignored //
			// //////////////////////////////////////////////////////////////////////////////// //

			if  zRecords.count > 0,
				let  zone = zRecords[0] as? Zone,
				let cloud = gRemoteStorage.zRecords(for: dbID) {

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
					default:                 break
				}
			}
		}
	}

	@discardableResult func load(type: String, into dbID: ZDatabaseID?, using request: NSFetchRequest<NSFetchRequestResult>) -> ZRecordsArray {
		var records = ZRecordsArray()
		do {
			let items = try managedContext.fetch(request)
			var count = type == kZoneType ? 1 : items.count // only one Zone is needed
			for item in items {
				let       zRecord = item as! ZRecord

				if  let dbid      = dbID?.indicator,
					zRecord.dbid == dbid,
					count         > 0 {
					count        -= 1
					var converted = zRecord.convertFromCoreData(into: type, visited: lastConverted[dbid])

					zRecord.register()
					records.append(zRecord)

					if  type == kZoneType {
						converted.appendUnique(contentsOf: lastConverted[dbid] ?? [])

						lastConverted[dbid] = converted
					}
				}
			}
		} catch {
			print(error)
		}

		return records
	}

	@discardableResult
	func convertZoneFromCoreData(_ record: ZRecord, into dbID: ZDatabaseID?) -> [String] {
		var converted = [String]()

		if  let  dbid = dbID?.indicator {
			converted = record.convertFromCoreData(into: kZoneType, visited: lastConverted[dbid])

			converted.appendUnique(contentsOf: lastConverted[dbid] ?? [])

			lastConverted[dbid] = converted
		}

		return converted
	}

}
