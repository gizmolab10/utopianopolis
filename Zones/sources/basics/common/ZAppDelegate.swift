//
//  ZAppDelegate.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/3/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

func gSaveContext() { if gUseCoreData { gAppDelegate?.saveContext() } }
var gManagedContext : NSManagedObjectContext? = { return gAppDelegate?.managedContext }()
var gCoreDataURL    :                     URL = { return gDataURL.appendingPathComponent("data") }()
var gDataURL        :                     URL = { return try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Seriously", isDirectory: true) }()

class ZAppDelegate: NSResponder, ZApplicationDelegate {

	let localURL            = gCoreDataURL.appendingPathComponent("local.store")
	let cloudURL            = gCoreDataURL.appendingPathComponent("cloud.store")
	var storesNeeded        = true
	lazy var model          : NSManagedObjectModel          = { return NSManagedObjectModel.mergedModel(from: nil)! }()
	lazy var coordinator    : NSPersistentStoreCoordinator? = { return persistentContainer.persistentStoreCoordinator }()
	lazy var managedContext : NSManagedObjectContext        = { return persistentContainer.viewContext }()

	lazy var localDescription: NSPersistentStoreDescription = {
		// Create a store description for a local store
		let           desc = NSPersistentStoreDescription(url: localURL)
		desc.configuration = "Local"

		return desc
	}()

	lazy var privateDescription: NSPersistentStoreDescription = {
		// Create a store description for a CloudKit-backed local store
		let                        id = "iCloud.com.zones.Zones"
		let                   options = NSPersistentCloudKitContainerOptions(containerIdentifier: id)
		let                      desc = NSPersistentStoreDescription(url: cloudURL)
		desc.configuration            = "Cloud"
		desc.cloudKitContainerOptions = options

		return desc
	}()

	lazy var publicDescription: NSPersistentStoreDescription = {
		let desc = privateDescription.copy() as! NSPersistentStoreDescription
//		desc.cloudKitContainerOptions?.databaseScope = .public // default is private
		return desc
	}()

	lazy var persistentContainer: NSPersistentCloudKitContainer = {
		let container = NSPersistentCloudKitContainer(name: "seriously", managedObjectModel: model)

		ValueTransformer.setValueTransformer(  ZReferenceTransformer(), forName:   gReferenceTransformerName)
		ValueTransformer.setValueTransformer( ZAssetArrayTransformer(), forName:  gAssetArrayTransformerName)
		ValueTransformer.setValueTransformer(ZStringArrayTransformer(), forName: gStringArrayTransformerName)

		// Update the container's list of store descriptions
		container.persistentStoreDescriptions = [
			publicDescription,
			localDescription
		]

		container.loadPersistentStores() { (storeDescription, iError) in
			if  let         error = iError as NSError? {
				fatalError("Unresolved error \(error), \(error.userInfo)")
			} else {
				self.storesNeeded = false
			}
		}

		container.viewContext.mergePolicy                          = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
		container.viewContext.automaticallyMergesChangesFromParent = true

		return container
	}()

	func saveContext() {
		if  let context = gManagedContext, context.hasChanges {
			do {
				try context.save()
			} catch {
				// Replace this implementation with code to handle the error appropriately.
				// fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
				let nserror = error as NSError
				fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
			}
		}
	}

}
