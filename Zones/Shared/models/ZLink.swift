//
//  ZLink.swift
//  Zones
//
//  Created by Jonathan Sand on 7/24/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import CoreData


public class ZLink: NSManagedObject {
    var            type: String?
    @NSManaged var from: Zone?
    @NSManaged var   to: Zone?
}