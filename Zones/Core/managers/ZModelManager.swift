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
    let   currentDB: CKDatabase!
    var currentZone: Zone!
    var    closures: [UpdateClosureObject] = [UpdateClosureObject]()
    var     records: [CKRecordID : ZBase]  = [:]


    init() {
        container = CKContainer(identifier: "iCloud.com.zones.Zones")
        currentDB = container.privateCloudDatabase

        registerForCloudKitNotifications()
        setupRootZone()
    }


    // MARK:- closures
    // MARK:-


    func registerUpdateClosure(_ closure: @escaping UpdateClosure) {
        closures.append(UpdateClosureObject(iClosure: closure))
    }


    func updateClosures(with: UpdateKind) {
        DispatchQueue.main.async(execute: {
            for object: UpdateClosureObject in self.closures {
                object.closure(with)
            }
        })
    }


    // MARK:- records
    // MARK:-


    func registerObject(_ object: ZBase) {
        records[object.record.recordID] = object
    }


    func setupRootZone() {
        let currentZoneID: CKRecordID = CKRecordID.init(recordName: "root")

        updateReccord(currentZoneID, onCompletion: { (record: CKRecord?) -> (Void) in
            self.currentZone = Zone(record: record!, database: self.currentDB)
            self.updateClosures(with: UpdateKind.data)
        })
    }


    public func receivedUpdateFor(_ recordID: CKRecordID) {
        updateReccord(recordID, onCompletion: { (record: CKRecord) -> (Void) in
            let    object = self.records[record.recordID]! as ZBase
            object.record = record

            self.updateClosures(with: UpdateKind.data)
        })
    }


    func updateReccord(_ recordID: CKRecordID, onCompletion: @escaping RecordClosure) {
        currentDB.fetch(withRecordID: recordID) { (fetched: CKRecord?, fetchError: Error?) in
            if (fetchError == nil) {
                onCompletion(fetched!)
            } else {
                let created: CKRecord = CKRecord.init(recordType: "Zone", recordID: recordID)
                created["zoneName"] = "root" as CKRecordValue?

                self.currentDB.save(created, completionHandler: { (saved: CKRecord?, saveError: Error?) in
                    if (saveError == nil) {
                        onCompletion(saved!)
                    }
                })
            }
        }
    }


    func className(of:AnyObject) -> String {
        return NSStringFromClass(type(of: of)) as String
    }


    // MARK:- persistence
    // MARK:-


    func registerForCloudKitNotifications() {
        currentDB.fetchAllSubscriptions { (iSubscriptions: [CKSubscription]?, iError: Error?) in
            var count: Int = iSubscriptions!.count

            if count == 0 {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: 1 * NSEC_PER_SEC), execute: {
                    self.subscribe()
                })
            } else {
                for subscription: CKSubscription in iSubscriptions! {
                    self.currentDB.delete(withSubscriptionID: subscription.subscriptionID, completionHandler: { (iSubscription: String?, iError: Error?) in
                        if iError != nil {
                            print(iError)
                        } else {
                            count -= 1

                            if count == 0 {
                                self.subscribe()
                            }
                        }
                    })
                }
            }
        }
    }


    func subscribe() {
        let classNames = ["Zone"] //, "ZTrait", "ZLink", "ZAction"]

        for className: String in classNames {
            let    predicate:          NSPredicate = NSPredicate(value: true)
            let subscription:       CKSubscription = CKSubscription(recordType: className, predicate: predicate, options: [.firesOnRecordUpdate])
            let  information:   CKNotificationInfo = CKNotificationInfo()
            information.alertLocalizationKey       = "somthing has changed, hah!";
            information.shouldBadge                = true
            information.shouldSendContentAvailable = true
            subscription.notificationInfo          = information

            self.currentDB.save(subscription, completionHandler: { (iSubscription: CKSubscription?, iError: Error?) in
                if iError != nil {
                    self.updateClosures(with: UpdateKind.error)

                    print(iError)
                }
            })
        }
    }


    func set(intoObject: ZBase, itsPropertyName: String, withValue: NSObject) {
        let     record:       CKRecord = intoObject.record
        let identifier:    CKRecordID! = record.recordID
        let   oldValue: CKRecordValue! = record[itsPropertyName]
        let   newValue: CKRecordValue! = (withValue as! CKRecordValue)
        let  hasChange:           Bool = (oldValue as! NSObject != newValue as! NSObject)

        if (identifier != nil) && hasChange {
            currentDB.fetch(withRecordID: identifier) { (fetched: CKRecord?, fetchError: Error?) in
                if fetchError != nil {
                    record[itsPropertyName]   = newValue
                    intoObject.unsaved        = true

                    intoObject.updateProperties()
                    self.updateClosures(with: UpdateKind.data)
                } else {
                    fetched![itsPropertyName] = newValue
                    intoObject.unsaved        = false
                    intoObject.record         = fetched!

                    self.currentDB.save(fetched!, completionHandler: { (saved: CKRecord?, saveError: Error?) in
                        if saveError != nil {
                            self.updateClosures(with: UpdateKind.error)
                        } else {
                            self.updateClosures(with: UpdateKind.data)
                        }
                    })
                }
            }
        }
    }


    func get(fromObject: ZBase, valueForPropertyName: String) {
        if fromObject.record != nil {
            let      predicate = NSPredicate(format: "")
            let  type: String  = className(of: fromObject);
            let query: CKQuery = CKQuery(recordType: type, predicate: predicate)

            self.currentDB.perform(query, inZoneWith: nil) { (iResults: [CKRecord]?, performanceError: Error?) in
                if performanceError != nil {
                    self.updateClosures(with: UpdateKind.error)
                } else {
                    let        record: CKRecord = (iResults?[0])!
                    fromObject.record[valueForPropertyName] = (record as! CKRecordValue)

                    self.updateClosures(with: UpdateKind.data)
                }
            }
        }
    }
}

