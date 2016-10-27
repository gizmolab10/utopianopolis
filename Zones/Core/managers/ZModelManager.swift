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
    case delete
}


typealias UpdateClosure = (UpdateKind, NSObject?) -> (Void)


class UpdateClosureObject {
    let closure: UpdateClosure!

    init(iClosure: @escaping UpdateClosure) {
        closure = iClosure
    }
}


let modelManager = ZModelManager()
let   parentsKey = "parents"
let  rootNameKey = "root"
let  zoneTypeKey = "Zone"
let      cloudID = "iCloud.com.zones.Zones"


class ZModelManager {
    var    _rootZone: Zone!
    var selectedZone: Zone?
    var     closures: [UpdateClosureObject] = []
    var      records: [CKRecordID : ZBase]  = [:]
    let    container: CKContainer!
    let    currentDB: CKDatabase!


    init() {
        container = CKContainer(identifier: cloudID)
        currentDB = container.privateCloudDatabase

        stateManager.setupAndRun()
    }


    var rootZone: Zone! {
        set { _rootZone = newValue}
        get {
            if  _rootZone == nil {
                _rootZone = Zone(record: nil, database: currentDB)
            }

            return _rootZone
        }
    }


    // MARK:- closures
    // MARK:-


    func registerUpdateClosure(_ closure: @escaping UpdateClosure) {
        closures.append(UpdateClosureObject(iClosure: closure))
    }


    func updateToClosures(with: UpdateKind, object: NSObject?) {
        DispatchQueue.main.async(execute: {
            self.resetBadgeCounter()

            for closureObject: UpdateClosureObject in self.closures {
                closureObject.closure(with, object)
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
        let             record = CKRecord(recordType: zoneTypeKey)
        let               zone = Zone(record: record, database: currentDB)
        zone.links[parentsKey] = [rootZone]

        rootZone.children.append(zone)
        updateToClosures(with: UpdateKind.data, object: nil)
        persistenceManager.save()

        currentDB.save(record) { (iRecord: CKRecord?, iError: Error?) in
            if iError != nil {
                print(iError)
            } else {
                zone.record = iRecord
            }
        }
    }


    func deleteSelectedZone() {
        if let zone: Zone = selectedZone {
            let index = rootZone.children.index(of: zone)

            rootZone.children.remove(at: index!)
            persistenceManager.save()

            currentDB.delete(withRecordID: zone.record.recordID, completionHandler: { (deleted, error) in
                self.updateToClosures(with: UpdateKind.delete, object: zone)
            })
        }
    }

    func setupRootZoneWith(operation: BlockOperation) {
        let recordID: CKRecordID = CKRecordID(recordName: rootNameKey)

        assureRecordExists(withRecordID: recordID, onCompletion: { (record: CKRecord?) -> (Void) in
            if self.rootZone != nil {
                self.rootZone.record = record
            } else {
                record![zoneNameKey] = rootNameKey as CKRecordValue?
                self.rootZone        = Zone(record: record!, database: self.currentDB)
            }

            self.updateToClosures(with: UpdateKind.data, object: nil)
            operation.finish()
        })
    }


    func receivedUpdateFor(_ recordID: CKRecordID) {
        resetBadgeCounter()
        assureRecordExists(withRecordID: recordID, onCompletion: { (iRecord: CKRecord) -> (Void) in
            DispatchQueue.main.async(execute: {
                if let     object = self.records[iRecord.recordID] as ZBase? {
                    object.record = iRecord

                    self.updateToClosures(with: .data, object: nil)
                }
            })
        })
    }


    func assureRecordExists(withRecordID recordID: CKRecordID, onCompletion: @escaping RecordClosure) {
        currentDB.fetch(withRecordID: recordID) { (fetched: CKRecord?, fetchError: Error?) in
            if (fetchError == nil) {
                onCompletion(fetched!)
            } else {
                let created: CKRecord = CKRecord(recordType: zoneTypeKey, recordID: recordID)

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

            currentDB.save(subscription, completionHandler: { (iSubscription: CKSubscription?, iSaveError: Error?) in
                if iSaveError != nil {
                    self.updateToClosures(with: UpdateKind.error, object: iSaveError as NSObject?)

                    print(iSaveError)
                }

                count -= 1

                if count == 0 {
                    operation.finish()
                }
            })
        }
    }


    func setIntoObject(_ object: ZBase, value: NSObject, forPropertyName: String) {
        var                  hasChange = true
        var identifier:    CKRecordID?
        let   newValue: CKRecordValue! = (value as! CKRecordValue)
        let     record:      CKRecord? = object.record

        if record != nil {
            let oldValue: CKRecordValue! = record![forPropertyName]
            identifier                   = record?.recordID
            hasChange                    = oldValue == nil || (oldValue as! NSObject != newValue as! NSObject)
        }

        if hasChange {
            object.unsaved = true

            if (identifier != nil) {
                currentDB.fetch(withRecordID: identifier!) { (fetched: CKRecord?, fetchError: Error?) in
                    if fetchError != nil {
                        record?[forPropertyName]  = newValue

                        object.updateProperties()
                        self.updateToClosures(with: .data, object: nil)
                    } else {
                        fetched![forPropertyName] = newValue

                        self.currentDB.save(fetched!, completionHandler: { (saved: CKRecord?, saveError: Error?) in
                            if saveError != nil {
                                self.updateToClosures(with: .error, object: saveError as NSObject?)
                            } else {
                                object.record  = saved!
                                object.unsaved = false
                                self.updateToClosures(with: .data, object: nil)
                                persistenceManager.save()
                            }
                        })
                    }
                }
            }
        }
    }


    func getFromObject(_ object: ZBase, valueForPropertyName: String) {
        if object.record != nil && stateManager.isReady {
            let      predicate = NSPredicate(format: "")
            let  type: String  = className(of: object);
            let query: CKQuery = CKQuery(recordType: type, predicate: predicate)

            currentDB.perform(query, inZoneWith: nil) { (iResults: [CKRecord]?, performanceError: Error?) in
                if performanceError != nil {
                    self.updateToClosures(with: UpdateKind.error, object: performanceError as NSObject?)
                } else {
                    let        record: CKRecord = (iResults?[0])!
                    object.record[valueForPropertyName] = (record as! CKRecordValue)

                    self.updateToClosures(with: .data, object: nil)
                }
            }
        }
    }
}

