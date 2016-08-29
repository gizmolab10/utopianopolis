//
//  Zone+CoreDataProperties.swift
//  Zones
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Zones. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Zone {

    @NSManaged var zoneName: String?
    @NSManaged var actions: NSSet?
    @NSManaged var backlinks: NSSet?
    @NSManaged var links: NSSet?
    @NSManaged var traits: NSSet?

}
