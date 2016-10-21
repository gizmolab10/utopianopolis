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
    var _selectedZone: Zone!
    var      closures: [UpdateClosureObject] = [UpdateClosureObject]()
    var       records: [CKRecordID : ZBase]  = [:]
    let     container: CKContainer!
    let     currentDB: CKDatabase!
    let    parentsKey = "parents"
    let   zoneNameKey = "zoneName"
    let   rootNameKey = "root"
    let   zoneTypeKey = "Zone"
    let       cloudID = "iCloud.com.zones.Zones"


    init() {
        container = CKContainer(identifier: cloudID)
        currentDB = container.privateCloudDatabase

        stateManager.setupAndRun()
    }


    var selectedZone: Zone! {
        set { _selectedZone = newValue}
        get {
            if  _selectedZone == nil {
                _selectedZone = Zone(record: nil, database: self.currentDB)
            }

            return _selectedZone
        }
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
        let record = CKRecord(recordType: zoneTypeKey)

        currentDB.save(record) { (iRecord: CKRecord?, iError: Error?) in
            if iError != nil {
                print(iError)
            } else {
                let                    zone = Zone(record: iRecord, database: self.currentDB)
                zone.links[self.parentsKey] = [self.selectedZone]

                self.selectedZone.children.append(zone)
                persistenceManager.save()
            }
        }
    }


    func setupRootZone() {
        let recordID: CKRecordID = CKRecordID(recordName: rootNameKey)

        self.assureRecordExists(withRecordID: recordID, onCompletion: { (record: CKRecord?) -> (Void) in
            if self.selectedZone != nil {
                self.selectedZone.record = record
            } else {
                record![self.zoneNameKey] = self.rootNameKey as CKRecordValue?
                self.selectedZone         = Zone(record: record!, database: self.currentDB)
            }


            self.updateClosures(with: UpdateKind.data)
        })
    }


    func receivedUpdateFor(_ recordID: CKRecordID) {
        resetBadgeCounter()
        assureRecordExists(withRecordID: recordID, onCompletion: { (iRecord: CKRecord) -> (Void) in
            DispatchQueue.main.async(execute: {
                if let     object = self.records[iRecord.recordID] as ZBase? {
                    object.record = iRecord

                    self.updateClosures(with: .data)
                }
            })
        })
    }


    func assureRecordExists(withRecordID recordID: CKRecordID, onCompletion: @escaping RecordClosure) {
        currentDB.fetch(withRecordID: recordID) { (fetched: CKRecord?, fetchError: Error?) in
            if (fetchError == nil) {
                onCompletion(fetched!)
            } else {
                let created: CKRecord = CKRecord(recordType: self.zoneTypeKey, recordID: recordID)

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


    func unsubscribeWith(operation: BlockOperation) {
        currentDB.fetchAllSubscriptions { (iSubscriptions: [CKSubscription]?, iError: Error?) in
            if iError != nil {
                print(iError)
            } else {
                var count: Int = iSubscriptions!.count

                if count == 0 {
                    operation.finish()
                } else {
                    for subscription: CKSubscription in iSubscriptions! {
                        self.currentDB.delete(withSubscriptionID: subscription.subscriptionID, completionHandler: { (iSubscription: String?, iDeleteError: Error?) in
                            if iDeleteError != nil {
                                print(iDeleteError)
                            }

                            count -= 1

                            if count == 0 {
                                operation.finish()
                            }
                        })
                    }
                }
            }
        }
    }


    func subscribeWith(operation: BlockOperation) {
        let classNames = [zoneTypeKey] //, "ZTrait", "ZAction"]
        var count = classNames.count


        for className: String in classNames {
            let    predicate:          NSPredicate = NSPredicate(value: true)
            let subscription:       CKSubscription = CKSubscription(recordType: className, predicate: predicate, options: [.firesOnRecordUpdate])
            let  information:   CKNotificationInfo = CKNotificationInfo()
            information.alertLocalizationKey       = "somthing has changed, hah!";
            information.shouldBadge                = true
            information.shouldSendContentAvailable = true
            subscription.notificationInfo          = information

            self.currentDB.save(subscription, completionHandler: { (iSubscription: CKSubscription?, iSaveError: Error?) in
                if iSaveError != nil {
                    self.updateClosures(with: UpdateKind.error)

                    print(iSaveError)
                }

                count -= 1

                if count == 0 {
                    operation.finish()
                }
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

