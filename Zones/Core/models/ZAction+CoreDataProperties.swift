//
//  ZAction+CoreDataProperties.swift
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

extension ZAction {

    @NSManaged var zoneName: String?
    @NSManaged var owner: Zone?

}
