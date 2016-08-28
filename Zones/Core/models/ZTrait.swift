//
//  ZTrait.swift
//  Zones
//
//  Created by Jonathan Sand on 7/24/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import CoreData


public class ZTrait: NSManagedObject {
    public var              key: String?
    public var             type: String?
    public var            value: NSData?
    @NSManaged public var owner: Zone!
}