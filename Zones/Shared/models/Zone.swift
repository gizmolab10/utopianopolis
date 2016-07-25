//
//  Zone.swift
//  Zones
//
//  Created by Jonathan Sand on 7/24/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import CoreData


public class Zone: NSManagedObject {
    var                 name: String?
    @NSManaged var   actions: [ZAction]
    @NSManaged var backlinks: [ZLink]
    @NSManaged var     links: [ZLink]
    @NSManaged var    traits: [ZTrait]
}