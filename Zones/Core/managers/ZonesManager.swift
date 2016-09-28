//
//  ZonesManager.swift
//  Zones
//
//  Created by Jonathan Sand on 8/6/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


public class ZonesManager: NSObject {


    func root() -> Zone {
        let request: NSFetchRequest <NSFetchRequestResult> = NSFetchRequest(entityName: "Zone")

        do {
            let zones = try managedObjectContext.fetch(request) as! [Zone]

            if (zones.count > 0) {
                return zones[0]
            }
        } catch {}

        let root = newZone(value: "iPad")

        do {
            try managedObjectContext.save()
        } catch {
            fatalError("Failure to save context: \(error)")
        }

        return root;
    }


    func newZone(value: String) -> Zone {
        let      zone = NSEntityDescription.insertNewObject(forEntityName: "Zone", into: managedObjectContext) as! Zone
        let     trait = newTrait()
        zone.zoneName = value
        trait.owner   = zone

        zone.mutableSetValue(forKey: "traits").add(trait)

        return zone
    }


    func newTrait() -> ZTrait {
        let trait = NSEntityDescription.insertNewObject(forEntityName: "ZTrait", into: managedObjectContext) as! ZTrait

        return trait
    }


}
