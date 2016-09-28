//
//  ZBase.swift
//  Zones
//
//  Created by Jonathan Sand on 9/19/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZBase {


    func setter(propertyName:NSString, value:NSObject) {

    }


    func getter(propertyName:NSString) -> NSObject? {
        
    }


    func fetchEstablishments(location:CLLocation, radiusInMeters:CLLocationDistance) {
        // 1
        let radiusInKilometers = radiusInMeters / 1000.0
        // 2
        let predicate = NSPredicate(format: "distanceToLocation:fromLocation:(%K,%@) &lt; %f", "Location", location, radiusInKilometers)
        // 3
        let query = CKQuery(recordType: EstablishmentType, predicate: predicate)
        // 4
        publicDB.performQuery(query, inZoneWithID: nil) { [unowned self] results, error in
            if let error = error {
                dispatch_async(dispatch_get_main_queue()) {
                    self.delegate?.errorUpdating(error)
                    print("Cloud Query Error - Fetch Establishments: \(error)")
                }
                return
            }

            self.items.removeAll(keepCapacity: true)
            results?.forEach({ (record: CKRecord) in
                self.items.append(Establishment(record: record,
                                                database: self.publicDB))
            })
            
            dispatch_async(dispatch_get_main_queue()) {
                self.delegate?.modelUpdated()
            }
        }
    }

}
