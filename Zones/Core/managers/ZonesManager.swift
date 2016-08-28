//
//  ZonesManager.swift
//  Zones
//
//  Created by Jonathan Sand on 8/6/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import CoreData


public class ZonesManager: NSObject {


    public func root() -> Zone {
        let request: NSFetchRequest = NSFetchRequest(entityName: "Zone")

        do {
            let zones = try managedObjectContext.executeFetchRequest(request) as! [Zone]

            if (zones.count > 0) {
                return zones[0]
            }
        } catch {}

        let zone = newZone("root")

        do {
            try managedObjectContext.save()
        } catch {
            fatalError("Failure to save context: \(error)")
        }

        return zone;
    }


    public func newZone(value: String) -> Zone {
        let    zone = NSEntityDescription.insertNewObjectForEntityForName("Zone", inManagedObjectContext: managedObjectContext) as! Zone
        let   trait = newTrait()
        trait.owner = zone
        zone.value  = value

        zone.mutableSetValueForKey("traits").addObject(trait)

        return zone
    }


    public func newTrait() -> ZTrait {
        let trait = NSEntityDescription.insertNewObjectForEntityForName("ZTrait", inManagedObjectContext: managedObjectContext) as! ZTrait

        return trait
    }


}