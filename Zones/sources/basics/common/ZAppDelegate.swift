//
//  ZAppDelegate.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/3/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

func gSaveContext() { if gUseCoreData { gDesktopAppDelegate?.saveContext() } }
var gManagedContext: NSManagedObjectContext? = { return gDesktopAppDelegate?.managedContext }()

class ZAppDelegate: NSResponder, ZApplicationDelegate {

	var localStore       : NSPersistentStore?
	var cloudStore       : NSPersistentStore?
	let localPath = "\(kPathToLocalStore)local.store"
	let cloudPath = "\(kPathToLocalStore)cloud.store"

	lazy var managedContext: NSManagedObjectContext = {
		let context: NSManagedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
		context.persistentStoreCoordinator = coordinator

		return context
	}()

	lazy var coordinator : NSPersistentStoreCoordinator? = {
		var storeCoordinator: NSPersistentStoreCoordinator?

		if  let model = NSManagedObjectModel.mergedModel(from: nil) {
			storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
		}

		return storeCoordinator
	}()

	lazy var localDescription: NSPersistentStoreDescription = {
		// Create a store description for a local store
		let           desc = NSPersistentStoreDescription(url: URL(fileURLWithPath: localPath))
		desc.configuration = "Local"

		return desc
	}()

	lazy var privateDescription: NSPersistentStoreDescription = {
		// Create a store description for a CloudKit-backed local store
		let                        id = "iCloud.com.zones.Zones"
		let                   options = NSPersistentCloudKitContainerOptions(containerIdentifier: id)
		let                      desc = NSPersistentStoreDescription(url: URL(fileURLWithPath: cloudPath))
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
		let container = NSPersistentCloudKitContainer(name: "seriously")

		// Update the container's list of store descriptions
		container.persistentStoreDescriptions = [
			publicDescription,
			localDescription
		]
		
		container.loadPersistentStores() { (storeDescription, error) in
			if  let error = error as NSError? {
				fatalError("Unresolved error \(error), \(error.userInfo)")
			}
		}

		return container
	}()

	func saveContext() {
		if  let context = gManagedContext, context.hasChanges, false {
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
