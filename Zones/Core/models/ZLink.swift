//
//  ZLink.swift
//  Zones
//
//  Created by Jonathan Sand on 7/24/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import CoreData


public class ZLink: NSManagedObject {
    public var            type: String?
    @NSManaged public var from: Zone
    @NSManaged public var   to: Zone
}