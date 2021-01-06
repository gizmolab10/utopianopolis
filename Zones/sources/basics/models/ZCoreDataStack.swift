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
func gLoadContext() { gCoreDataStack.loadContext() }
func gSaveContext() { gCoreDataStack.saveContext() }

class ZCoreDataStack: NSObject {

	let localURL            = gCoreDataURL.appendingPathComponent("local.store")
	let cloudURL            = gCoreDataURL.appendingPathComponent("cloud.store")
	lazy var model          : NSManagedObjectModel          = { return NSManagedObjectModel.mergedModel(from: nil)! }()
	lazy var coordinator    : NSPersistentStoreCoordinator? = { return persistentContainer.persistentStoreCoordinator }()
	lazy var managedContext : NSManagedObjectContext        = { return persistentContainer.viewContext }()

	lazy var localDescription: NSPersistentStoreDescription = {
		let           desc = NSPersistentStoreDescription(url: localURL)
		desc.configuration = "Local"

		return desc
	}()

	lazy var publicDescription: NSPersistentStoreDescription = {
		let desc = privateDescription.copy() as! NSPersistentStoreDescription
//		desc.cloudKitContainerOptions?.databaseScope = .public // default is private
		return desc
	}()

	lazy var privateDescription: NSPersistentStoreDescription = {
		let                        id = "iCloud.com.zones.Zones"
		let                   options = NSPersistentCloudKitContainerOptions(containerIdentifier: id)
		let                      desc = NSPersistentStoreDescription(url: cloudURL)
		desc.configuration            = "Cloud"
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

	func loadContext() {
		if  gUseCoreData {
			loadAllZones()

			for type in [kManifestType, kTraitType] {
				load(type: type, using: NSFetchRequest<NSFetchRequestResult>(entityName: type))
			}
		}
	}

	func loadAllZones() {
		loadZones(with: NSPredicate(format: "parentRID == \"root\""))
	}

	func loadZones(with predicate: NSPredicate) {
		let       request = NSFetchRequest<NSFetchRequestResult>(entityName: kZoneType)
		request.predicate = predicate

		if  let ids = load(type: kZoneType, using: request), ids.count > 0 {
			loadZones(with: NSPredicate(format: "parentRID IN %@", ids))
		}
	}

	@discardableResult func load(type: String, using request: NSFetchRequest<NSFetchRequestResult>) -> [String?]? {
		do {
			let      items = try managedContext.fetch(request)
			let        ids = items.map { (item) -> String in
				let record = item as! ZRecord

				record.convertFromCoreData(into: type)

				return record.record!.recordID.recordName
			}

			return ids
		} catch {
			print(error)
		}

		return nil
	}

}
