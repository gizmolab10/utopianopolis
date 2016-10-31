//
//  ZCloudManager.swift
//  Zones
//
//  Created by Jonathan Sand on 9/18/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZCloudManager {
    var   records: [CKRecordID : ZRecord]  = [:]
    let container: CKContainer!
    let currentDB: CKDatabase!


    init() {
        container = CKContainer(identifier: cloudID)
        currentDB = container.publicCloudDatabase

        stateManager.setupAndRun()
    }


    // MARK:- records
    // MARK:-


    func flush() {
        var recordsToSave: [CKRecord] = []
        let                 operation = CKModifyRecordsOperation()
        operation.container           = container
        operation.qualityOfService    = .background

        zonesManager.rootZone.resolveParents()

        for base: ZRecord in records.values {
            //  if base.recordState == .needsSave {
                recordsToSave.append(base.record)
            // }
        }

        operation.recordsToSave = recordsToSave

        operation.start()
    }


    func registerObject(_ object: ZRecord) {
        if object.record != nil {
            records[object.record.recordID] = object
        }
    }


    func objectForRecordID(_ recordID: CKRecordID) -> ZRecord? {
        return records[recordID]
    }


    func fetchReferencesTo(_ parent: Zone) {
        let reference: CKReference = CKReference(recordID: parent.record.recordID, action: .none)
        let predicate: NSPredicate = NSPredicate(format: "parent == %@", reference)
        let     query:     CKQuery = CKQuery(recordType: zoneTypeKey, predicate: predicate)

        currentDB.perform(query, inZoneWith: nil) { (records, error) in
            if error != nil {
                print(error)
            }

            if records != nil && (records?.count)! > 0 {
                for record: CKRecord in records! {
                    var zone: Zone? = self.objectForRecordID(record.recordID) as! Zone?

                    if zone == nil {
                        zone = Zone(record: record, database: self.currentDB)
                        
                        self.registerObject(zone!)
                        parent.children.append(zone!)
                        self.fetchReferencesTo(zone!)
                    }
                }

                zonesManager.updateToClosures(nil, regarding: .data)
            }
        }
    }


    func setupRootWith(operation: BlockOperation) {
        let recordID: CKRecordID = CKRecordID(recordName: rootNameKey)

        assureRecordExists(withRecordID: recordID, onCompletion: { (record: CKRecord?) -> (Void) in
            var root: Zone? = zonesManager.rootZone

            if root != nil {
                root?.record = record
            } else {
                record![zoneNameKey]  = rootNameKey as CKRecordValue?
                root                  = Zone(record: record!, database: self.currentDB)
                zonesManager.rootZone = root

                root?.saveToCloud()
            }

            root?.fetchChildren()
            zonesManager.updateToClosures(nil, regarding: .data)
            operation.finish()
        })
    }


    func receivedUpdateFor(_ recordID: CKRecordID) {
        resetBadgeCounter()
        assureRecordExists(withRecordID: recordID, onCompletion: { (iRecord: CKRecord) -> (Void) in
            DispatchQueue.main.async(execute: {
                if  let    generic = self.objectForRecordID(iRecord.recordID) {
                    generic.record = iRecord

                    generic.fetchChildren()

                    zonesManager.updateToClosures(nil, regarding: .data)
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
        container.accountStatus { (iStatus, iError) in
            if iStatus == .available {
                let badgeResetOperation = CKModifyBadgeOperation(badgeValue: 0)

                badgeResetOperation.modifyBadgeCompletionBlock = { (error) -> Void in
                    if error == nil {
//                        print("Error resetting badge: \(error)")
//                    } else {
                        zapplication.clearBadge()
                    }
                }

                self.container.add(badgeResetOperation)
            }
        }
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
                    zonesManager.updateToClosures(iSaveError as NSObject?, regarding: .error)

                    print(iSaveError)
                }

                count -= 1

                if count == 0 {
                    operation.finish()
                }
            })
        }
    }


    func setIntoObject(_ object: ZRecord, value: NSObject, forPropertyName: String) {
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
            object.recordState = .needsSave

            if (identifier != nil) {
                currentDB.fetch(withRecordID: identifier!) { (fetched: CKRecord?, fetchError: Error?) in
                    if fetchError != nil {
                        record?[forPropertyName]  = newValue

                        object.updateProperties()
                        zonesManager.updateToClosures(nil, regarding: .data)
                        object.saveToCloud()
                    } else {
                        fetched![forPropertyName] = newValue

                        self.currentDB.save(fetched!, completionHandler: { (saved: CKRecord?, saveError: Error?) in
                            if saveError != nil {
                                zonesManager.updateToClosures(saveError as NSObject?, regarding: .error)
                            } else {
                                object.record      = saved!
                                object.recordState = .ready

                                zonesManager.updateToClosures(nil, regarding: .data)
                                persistenceManager.save()
                            }
                        })
                    }
                }
            }
        }
    }


    func getFromObject(_ object: ZRecord, valueForPropertyName: String) {
        if object.record != nil && stateManager.isReady {
            let      predicate = NSPredicate(format: "")
            let  type: String  = className(of: object);
            let query: CKQuery = CKQuery(recordType: type, predicate: predicate)

            currentDB.perform(query, inZoneWith: nil) { (iResults: [CKRecord]?, performanceError: Error?) in
                if performanceError != nil {
                    zonesManager.updateToClosures(performanceError as NSObject?, regarding: .error)
                } else {
                    let        record: CKRecord = (iResults?[0])!
                    object.record[valueForPropertyName] = (record as! CKRecordValue)

                    zonesManager.updateToClosures(nil, regarding: .data)
                }
            }
        }
    }
}

