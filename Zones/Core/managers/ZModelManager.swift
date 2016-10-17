//
//  ZModelManager.swift
//  Zones
//
//  Created by Jonathan Sand on 9/18/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


enum UpdateKind: UInt {
    case data
    case error
}


typealias UpdateClosure = (UpdateKind) -> (Void)


class UpdateClosureObject {
    let closure: UpdateClosure!

    init(iClosure: @escaping UpdateClosure) {
        closure = iClosure
    }
}


let modelManager = ZModelManager()


class ZModelManager {
    let    container: CKContainer!
    let    currentDB: CKDatabase!
    var selectedZone: Zone!
    var     closures: [UpdateClosureObject] = [UpdateClosureObject]()
    var      records: [CKRecordID : ZBase]  = [:]


    init() {
        container = CKContainer(identifier: "iCloud.com.zones.Zones")
        currentDB = container.privateCloudDatabase

        stateManager.setupAndRun()
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
        if object.record != nil {
            records[object.record.recordID] = object
        }
    }


    func addNewZone() {
        let record = CKRecord(recordType: "Zone")

        currentDB.save(record) { (iRecord: CKRecord?, iError: Error?) in
            if iError != nil {
                print(iError)
            } else {
                let zone = Zone(record: iRecord, database: self.currentDB)

                self.selectedZone.children.append(zone)
            }
        }
    }


    func setupRootZone() {
        let identifier: CKRecordID = CKRecordID(recordName: "root")

        self.updateReccord(identifier, onCompletion: { (record: CKRecord?) -> (Void) in
            if self.selectedZone != nil {
                self.selectedZone.record = record
            } else {
                record!["zoneName"] = "root" as CKRecordValue?
                self.selectedZone   = Zone(record: record!, database: self.currentDB)
            }


            self.updateClosures(with: UpdateKind.data)
        })
    }


    func receivedUpdateFor(_ recordID: CKRecordID) {
        resetBadgeCounter()
        updateReccord(recordID, onCompletion: { (record: CKRecord) -> (Void) in
            DispatchQueue.main.async(execute: {
                let    object = self.records[record.recordID]! as ZBase
                object.record = record

                self.updateClosures(with: UpdateKind.data)
            })
        })
    }


    func updateReccord(_ recordID: CKRecordID, onCompletion: @escaping RecordClosure) {
        currentDB.fetch(withRecordID: recordID) { (fetched: CKRecord?, fetchError: Error?) in
            if (fetchError == nil) {
                onCompletion(fetched!)
            } else {
                let created: CKRecord = CKRecord(recordType: "Zone", recordID: recordID)

                self.currentDB.save(created, completionHandler: { (saved: CKRecord?, saveError: Error?) in
                    if (saveError == nil) {
                        onCompletion(saved!)
                        persistenceManager.save()
                    }
                })
            }
        }
    }


    func className(of:AnyObject) -> String {
        return NSStringFromClass(type(of: of)) as String
    }


    // MARK:- remote persistence
    // MARK:-


    func resetBadgeCounter() {
        let badgeResetOperation = CKModifyBadgeOperation(badgeValue: 0)

        badgeResetOperation.modifyBadgeCompletionBlock = { (error) -> Void in
            if error != nil {
                print("Error resetting badge: \(error)")
            } else {
                zapplication.clearBadge()
            }
        }

        container.add(badgeResetOperation)
    }


    func setupWith(operation: ZBlockOperation) {
        if  selectedZone == nil {
            let record = CKRecord(recordType: "Zone")

            currentDB.save(record) { (iRecord: CKRecord?, iError: Error?) in
                if iError != nil {
                    print(iError)
                } else {
                    self.selectedZone = Zone(record: iRecord, database: self.currentDB)
                }

                operation.done()
            }
        }
    }


    func registerWith(operation: ZBlockOperation) {
        currentDB.fetchAllSubscriptions { (iSubscriptions: [CKSubscription]?, iError: Error?) in
            if iError != nil {
                print(iError)
            } else {
                var count: Int = iSubscriptions!.count

                if count == 0 {
                    operation.done()
                } else {
                    for subscription: CKSubscription in iSubscriptions! {
                        self.currentDB.delete(withSubscriptionID: subscription.subscriptionID, completionHandler: { (iSubscription: String?, iDeleteError: Error?) in
                            if iDeleteError != nil {
                                print(iDeleteError)
                            } else {
                                count -= 1

                                if count == 0 {
                                    operation.done()
                                }
                            }
                        })
                    }
                }
            }
        }
    }


    func subscribeWith(operation: ZBlockOperation) {
        let classNames = ["Zone"] //, "ZTrait", "ZAction"]

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

                operation.done()
            })
        }
    }


    func set(intoObject: ZBase, itsPropertyName: String, withValue: NSObject) {
        let     record:       CKRecord = intoObject.record
        let identifier:    CKRecordID! = record.recordID
        let   oldValue: CKRecordValue! = record[itsPropertyName]
        let   newValue: CKRecordValue! = (withValue as! CKRecordValue)
        let  hasChange:           Bool = oldValue == nil || (oldValue as! NSObject != newValue as! NSObject)

        if (identifier != nil) && hasChange {
            intoObject.unsaved = true

            currentDB.fetch(withRecordID: identifier) { (fetched: CKRecord?, fetchError: Error?) in
                if fetchError != nil {
                    record[itsPropertyName]   = newValue

                    intoObject.updateProperties()
                    self.updateClosures(with: UpdateKind.data)
                } else {
                    fetched![itsPropertyName] = newValue

                    self.currentDB.save(fetched!, completionHandler: { (saved: CKRecord?, saveError: Error?) in
                        if saveError != nil {
                            self.updateClosures(with: UpdateKind.error)
                        } else {
                            intoObject.record  = saved!
                            intoObject.unsaved = false
                            self.updateClosures(with: UpdateKind.data)
                            persistenceManager.save()
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

