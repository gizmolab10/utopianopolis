//
//  Zone.swift
//  Zones
//
//  Created by Jonathan Sand on 7/24/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import CoreData


public class Zone: NSManagedObject {
    public var             zoneName: String?
    @NSManaged public var    traits: NSSet?
    @NSManaged public var   actions: NSSet?
    @NSManaged public var backlinks: NSSet?
    @NSManaged public var     links: NSSet?
}