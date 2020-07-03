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

		container.loadPersistentStores() { (storeDescription, error) in
			if  let error = error as NSError? {
				fatalError("Unresolved error \(error), \(error.userInfo)")
			}
		}

		return container
	}()

}
