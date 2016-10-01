//
//  ZModelManager.swift
//  Zones
//
//  Created by Jonathan Sand on 9/18/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


public enum UpdateKind: UInt {
    case data
    case error
}


public typealias UpdateClosure = (UpdateKind) -> (Void)


class UpdateClosureObject {
    let closure: UpdateClosure!

    init(iClosure: @escaping UpdateClosure) {
        closure = iClosure
    }
}


public let modelManager = ZModelManager()


public class ZModelManager {
    let   container: CKContainer!
    let   privateDB: CKDatabase!
    let    publicDB: CKDatabase!
    var currentZone: Zone!
    var    closures: [UpdateClosureObject] = [UpdateClosureObject]()


    init() {
        container = CKContainer(identifier: "iCloud.com.zones.Zones")
        privateDB = container.privateCloudDatabase
        publicDB  = container.publicCloudDatabase

        setupRoot()
    }


    func setupRoot() {
        let currentZoneID: CKRecordID = CKRecordID.init(recordName: "root")

        publicDB.fetch(withRecordID: currentZoneID) { (fetched: CKRecord?, fetchError: Error?) in
            if (fetchError == nil) {
                self.currentZone = Zone(record: fetched!, database: self.publicDB)
                self.update(with: UpdateKind.data)
            } else {
                let created: CKRecord = CKRecord.init(recordType: "Zone", recordID: currentZoneID)
                created["zoneName"] = "root" as CKRecordValue?

                self.publicDB.save(created, completionHandler: { (saved: CKRecord?, saveError: Error?) in
                    if (saveError == nil) {
                        self.currentZone = Zone(record: saved!, database: self.publicDB)
                        self.update(with: UpdateKind.data)
                    }
                })
            }
        }
    }


    public func register(closure: @escaping UpdateClosure) {
        closures.append(UpdateClosureObject(iClosure: closure))
    }


    func update(with: UpdateKind) {
        DispatchQueue.main.async(execute: {
            for object: UpdateClosureObject in self.closures {
                object.closure(with)
            }
        })
    }


    func className(of:AnyObject) -> String {
        return NSStringFromClass(type(of: of)) as String
    }


    func set(object:AnyObject, propertyName:NSString, withValue:NSObject) {

    }


    func get(object:AnyObject, propertyName:NSString) -> NSObject? {
//        let predicate = NSPredicate(format: "")
//        let type : String = className(of: object);
//        let query : CKQuery = CKQuery(recordType: type, predicate: predicate)
//
//        self.publicDB.performQuery(query, inZoneWithID: nil) { [unowned self] results, error in
//
//        }
        return nil
    }


//    func fetchEstablishments(location:CLLocation, radiusInMeters:CLLocationDistance) {
//        // 1
//        let radiusInKilometers = radiusInMeters / 1000.0
//        // 2
//        let predicate = NSPredicate(format: "distanceToLocation:fromLocation:(%K,%@) &lt; %f", "Location", location, radiusInKilometers)
//        // 3
//        let query = CKQuery(recordType: "Zone", predicate: predicate)
//        // 4
//        self.publicDB.performQuery(query, inZoneWithID: nil) { [unowned self] results, error in
////            if let error = error {
////                dispatch_async(dispatch_get_main_queue()) {
////                    self.delegate?.errorUpdating(error)
////                    print("Cloud Query Error - Fetch Establishments: \(error)")
////                }
//                return
//            }
//
//            self.items.removeAll(keepCapacity: true)
//            results?.forEach({ (record: CKRecord) in
//                self.items.append(Establishment(record: record,
//                                                database: self.publicDB))
//            })
//
//            dispatch_async(dispatch_get_main_queue()) {
//                self.delegate?.modelUpdated()
//            }
//        }
//    }
    

}

