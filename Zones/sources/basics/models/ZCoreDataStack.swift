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

	let cloudID             = "iCloud.com.zones.Zones"
	let localURL            = gCoreDataURL.appendingPathComponent("local.store")
	let publicURL           = gCoreDataURL.appendingPathComponent("cloud.public.store")
	let privateURL          = gCoreDataURL.appendingPathComponent("cloud.private.store")
	lazy var model          : NSManagedObjectModel          = { return NSManagedObjectModel.mergedModel(from: nil)! }()
	lazy var coordinator    : NSPersistentStoreCoordinator? = { return persistentContainer.persistentStoreCoordinator }()
	lazy var managedContext : NSManagedObjectContext        = { return persistentContainer.viewContext }()

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

	func loadContext() {
		if  gUseCoreData {
			let       request = NSFetchRequest<NSFetchRequestResult>(entityName: kZoneType)
			request.predicate = NSPredicate(format: "ckrid == \"root\"")

			FOREGROUND {
				let records = self.load(type: kZoneType, using: request)

				for record in records {
					if  let zone = record as? Zone,
						zone.isARoot {
						zone.traverseAllProgeny { iChild in
							iChild.respectOrder()
						}
					}
				}

				for type in [kManifestType, kTraitType] {
					self.load(type: type, using: NSFetchRequest<NSFetchRequestResult>(entityName: type))
				}
			}
		}
	}

	@discardableResult func load(type: String, using request: NSFetchRequest<NSFetchRequestResult>) -> ZRecordsArray {
		var records = ZRecordsArray()
		do {
			let items = try managedContext.fetch(request)
			for item in items {
				let record = item as! ZRecord
				records.append(record)
				record.convertFromCoreData(into: type)
			}
		} catch {
			print(error)
		}

		return records
	}

}
