//
//  ZTrait.swift
//  Zones
//
//  Created by Jonathan Sand on 7/24/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import CoreData


public class ZTrait: NSManagedObject {
    var              key: String?
    var             type: String?
    var            value: NSData?
    @NSManaged var owner: Zone?
}