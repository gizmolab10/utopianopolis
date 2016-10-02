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

        privateDB.fetch(withRecordID: currentZoneID) { (fetched: CKRecord?, fetchError: Error?) in
            if (fetchError == nil) {
                self.currentZone = Zone(record: fetched!, database: self.privateDB)
                self.update(with: UpdateKind.data)
            } else {
                let created: CKRecord = CKRecord.init(recordType: "Zone", recordID: currentZoneID)
                created["zoneName"] = "root" as CKRecordValue?

                self.privateDB.save(created, completionHandler: { (saved: CKRecord?, saveError: Error?) in
                    if (saveError == nil) {
                        self.currentZone = Zone(record: saved!, database: self.privateDB)
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


    func set(intoObject: ZBase, itsPropertyName: String, withValue: AnyObject) {
        intoObject.record[itsPropertyName] = (withValue as! CKRecordValue)

        self.privateDB.save(intoObject.record, completionHandler: { (saved: CKRecord?, saveError: Error?) in
            if saveError != nil {
                self.update(with: UpdateKind.error)
            } else {
                intoObject.record = saved
                self.update(with: UpdateKind.data)
            }
        })
    }


    func get(fromObject: ZBase, valueForPropertyName: String) {
        let      predicate = NSPredicate(format: "")
        let  type: String  = className(of: fromObject);
        let query: CKQuery = CKQuery(recordType: type, predicate: predicate)

        self.privateDB.perform(query, inZoneWith: nil) { (iResults: [CKRecord]?, iError: Error?) in
            if iError != nil {
                self.update(with: UpdateKind.error)
            } else {
                let        record: CKRecord = (iResults?[0])!
                fromObject.record[valueForPropertyName] = (record as! CKRecordValue)

                self.update(with: UpdateKind.data)
            }
        }
    }


}

