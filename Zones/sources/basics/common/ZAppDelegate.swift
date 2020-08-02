//
//  ZAppDelegate.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/3/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZAppDelegate: NSResponder, ZApplicationDelegate {

	lazy var persistentContainer: NSPersistentCloudKitContainer = {
		let container = NSPersistentCloudKitContainer(name: "Seriously")

		// Create a store description for a local store
		let localStoreLocation = URL(fileURLWithPath: kPathToLocalStore + "local.store")
		let localStoreDescription =
			NSPersistentStoreDescription(url: localStoreLocation)
		localStoreDescription.configuration = "Local"

		// Create a store description for a CloudKit-backed local store
		let cloudStoreLocation = URL(fileURLWithPath: kPathToLocalStore + "cloud.store")
		let cloudStoreDescription =
			NSPersistentStoreDescription(url: cloudStoreLocation)
		cloudStoreDescription.configuration = "Cloud"

		// Set the container options on the cloud store
		cloudStoreDescription.cloudKitContainerOptions =
			NSPersistentCloudKitContainerOptions(
				containerIdentifier: "iCloud.com.zones.Zones")

		// Update the container's list of store descriptions
		container.persistentStoreDescriptions = [
			cloudStoreDescription,
			localStoreDescription
		]
		
		container.loadPersistentStores() { (storeDescription, error) in
			if  let error = error as NSError? {
				fatalError("Unresolved error \(error), \(error.userInfo)")
			}
		}

		return container
	}()

}
