//
//  ZCloudManager.swift
//  Zones
//
//  Created by Jonathan Sand on 9/18/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZCloudManager: NSObject {
    var        records:          [CKRecordID : ZRecord] = [:]
    var cloudZonesByID: [CKRecordZoneID : CKRecordZone] = [:]
    var      container:                    CKContainer!
    var      currentDB:                     CKDatabase? { get { return databaseForMode(travelManager.storageMode) }     }


    func databaseForMode(_ mode: ZStorageMode) -> CKDatabase? {
        switch (mode) {
        case .everyone: return container.publicCloudDatabase
        case .group:    return container.sharedCloudDatabase
        case .mine:     return container.privateCloudDatabase
        default:        return nil
        }
    }


    func configure(_ operation: CKDatabaseOperation) -> CKDatabaseOperation? {
        if currentDB == nil {
            return nil
        }

        operation.qualityOfService = .background
        operation.container        = container
        operation.database         = currentDB

        return operation
    }


    func clear() {
        records.removeAll()
    }


    // MARK:- operations
    // MARK:-


    func fetchCloudZones(_ onCompletion: (() -> Swift.Void)?) {
        container = CKContainer(identifier: cloudID)

        travelManager.setup()

        if let                              operation = configure(CKFetchRecordZonesOperation()) as? CKFetchRecordZonesOperation {
            operation.fetchRecordZonesCompletionBlock = { (recordZonesByZoneID, operationError) -> Swift.Void in
                self.cloudZonesByID                   = recordZonesByZoneID!

                self.resetBadgeCounter()

                onCompletion?()
            }

            operation.start()
        }
    }


    func merge(_ onCompletion: (() -> Swift.Void)?) {
        if let        operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            operation.recordIDs = recordIDsMatching(.needsMerge)

            if (operation.recordIDs?.count)! > 0 {
                operation.completionBlock          = onCompletion
                operation.perRecordCompletionBlock = { (iRecord, iID, iError) in
                    if let error: CKError = iError as? CKError {
                        self.reportError(error)
                    } else if let zone: Zone = self.objectForRecordID(iID!) as? Zone {
                        zone.mergeIntoAndTake(iRecord!)
                    } else {
                        self.reportError("zoneless record")
                    }
                }

                operation.start()
                
                return
            }
        }

        onCompletion?()
    }


    func fetch(_ onCompletion: (() -> Swift.Void)?) {
        if let        operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            operation.recordIDs = recordIDsMatching(.needsFetch)

            if (operation.recordIDs?.count)! > 0 {
                operation.completionBlock          = onCompletion
                operation.perRecordCompletionBlock = { (iRecord, iID, iError) in
                    if let error: CKError = iError as? CKError {
                        self.reportError(error)
                    } else if let zone: Zone = self.objectForRecordID(iID!) as? Zone {
                        zone.recordState.remove(.needsFetch)

                        zone.record = iRecord
                    }
                }

                operation.start()
                
                return
            }
        }

        onCompletion?()
    }


    func royalFlush(_ onCompletion: (() -> Swift.Void)?) {
        for record in records.values {
            if !record.recordState.contains(.needsFetch) && !record.recordState.contains(.needsMerge) {
                record.needsSave()

                let zone = record as? Zone

                zone?.updateCloudProperties()
            }
        }

        flush(onCompletion)
    }


    func flush(_ onCompletion: (() -> Swift.Void)?) {
        if let operation = configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
            operation.recordsToSave                =   recordsMatching(.needsSave)
            operation.recordIDsToDelete            = recordIDsMatching(.needsDelete)

            if (operation.recordsToSave?.count)! > 0 || (operation.recordIDsToDelete?.count)! > 0 {
                operation.completionBlock          = onCompletion
                operation.perRecordCompletionBlock = { (iRecord, iError) -> Swift.Void in
                    if  let error:         CKError = iError as? CKError {
                        let info                   = error.errorUserInfo
                        var description:    String = info["ServerErrorDescription"] as! String

                        if  description           != "record to insert already exists" {
                            if let zone            = self.objectForRecordID((iRecord?.recordID)!) {
                                zone.needsFetch()
                            }

                            if let name            = iRecord?["zoneName"] as! String? {
                                description        = "\(description): \(name)"
                            }

                            self.reportError(description)
                        }
                    }

                    if let zone: Zone = self.objectForRecordID((iRecord?.recordID)!) as? Zone {
                        zone.recordState.remove(.needsSave)
                    }
                }
                
                operation.start()
                
                return
            }
        }

        onCompletion?()
    }


    @discardableResult func fetchChildren(_ onCompletion: (() -> Swift.Void)?) -> Bool {
        let childrenNeeded: [CKReference] = referencesMatching(.needsChildren)

        if childrenNeeded.count > 0, let operation = configure(CKQueryOperation()) as? CKQueryOperation {
            let                predicate = NSPredicate(format: "parent IN %@", childrenNeeded)
            operation.query              = CKQuery(recordType: zoneTypeKey, predicate: predicate)
            operation.desiredKeys        = ["parent", "zoneName"]
            operation.recordFetchedBlock = { iRecord -> Swift.Void in
                var zone = self.objectForRecordID(iRecord.recordID) as! Zone?

                if zone == nil {
                    zone = Zone(record: iRecord, storageMode: travelManager.storageMode)

                    self.registerObject(zone!)
                }

                zone?.needsChildren()

                if let parent = zone?.parentZone {
                    if !parent.children.contains(zone!) {
                        parent.children.append(zone!)
                    }
                } else {
                    self.reportError(zone)
                }
            }

            operation.queryCompletionBlock = { (cursor, error) -> Swift.Void in
                if error != nil {
                    self.reportError(error)
                }

                controllersManager.signal(nil, regarding: .data)

                self.fetchChildren(onCompletion)
            }

            operation.start()

            return false // false means more to do
        }

        onCompletion?()

        return true
    }


    // MARK:- records
    // MARK:-


    func recordIDsMatching(_ state: ZRecordState) -> [CKRecordID] {
        var identifiers: [CKRecordID] = []

        findRecordsMatching(state) { (object) -> (Void) in
            let record:       ZRecord = object as! ZRecord

            identifiers.append(record.record.recordID)
        }

        return identifiers
    }


    func recordsMatching(_ state: ZRecordState) -> [CKRecord] {
        var objects: [CKRecord] = []

        findRecordsMatching(state) { (object) -> (Void) in
            let record: ZRecord = object as! ZRecord

            objects.append(record.record)
        }

        return objects
    }


    func referencesMatching(_ state: ZRecordState) -> [CKReference] {
        var references:  [CKReference] = []

        findRecordsMatching(state) { (object) -> (Void) in
            let record:        ZRecord = object as! ZRecord
            let reference: CKReference = CKReference(recordID: record.record.recordID, action: .none)

            record.recordState.remove(state)
            references.append(reference)
        }

        return references
    }


    func findRecordsMatching(_ state: ZRecordState, onEach: ObjectClosure) {
        for record: ZRecord in records.values {
            if record.recordState.contains(state) {
                onEach(record)
            }
        }
    }
    

    func registerObject(_ object: ZRecord) {
        if object.record != nil {
            records[object.record.recordID] = object
        }
    }


    func objectForRecordID(_ recordID: CKRecordID) -> ZRecord? {
        return records[recordID]
    }


    func setupRoot(_ block: (() -> Swift.Void)?) {
        let recordID: CKRecordID = CKRecordID(recordName: rootNameKey)

        assureRecordExists(withRecordID: recordID, onCompletion: { (record: CKRecord?) -> (Void) in
            if record != nil {
                travelManager.hereZone.record = record

                travelManager.hereZone.needsFetch()
                travelManager.hereZone.needsChildren()
            }

            block?()
        })
    }


    func receivedUpdateFor(_ recordID: CKRecordID) {
        resetBadgeCounter()
        assureRecordExists(withRecordID: recordID, onCompletion: { (iRecord: CKRecord) -> (Void) in
            var zone: Zone? = self.objectForRecordID(iRecord.recordID) as! Zone?

            if  zone != nil {
                zone?.record = iRecord
            } else {
                zone = Zone(record: iRecord, storageMode: travelManager.storageMode)

                self.registerObject(zone!)
            }

            zone?.needsChildren()

            self.dispatchAsyncInForeground {
                controllersManager.signal(zone?.parentZone, regarding: .data)

                operationsManager.getChildren {
                    controllersManager.signal(zone?.parentZone, regarding: .data)
                }
            }
        } as! RecordClosure)
    }


    func assureRecordExists(withRecordID recordID: CKRecordID, onCompletion: @escaping RecordClosure) {
        if currentDB == nil {
            onCompletion(nil)
        } else {
            currentDB?.fetch(withRecordID: recordID) { (fetched: CKRecord?, fetchError: Error?) in
                if (fetchError == nil) {
                    onCompletion(fetched!)
                } else {
                    let created: CKRecord = CKRecord(recordType: zoneTypeKey, recordID: recordID)

                    self.currentDB?.save(created, completionHandler: { (saved: CKRecord?, saveError: Error?) in
                        if (saveError != nil) {
                            onCompletion(nil)
                        } else {
                            onCompletion(saved!)
                            zfileManager.save()
                        }
                    })
                }
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
                        zapplication.clearBadge()
                    }
                }

                self.container.add(badgeResetOperation)
            }
        }
    }


    func unsubscribe(_ block: (() -> Swift.Void)?) {
        if currentDB == nil {
            block?()
        } else {
            currentDB?.fetchAllSubscriptions { (iSubscriptions: [CKSubscription]?, iError: Error?) in
                if iError != nil {
                    block?()
                    self.reportError(iError)
                } else {
                    var count: Int = iSubscriptions!.count

                    if count == 0 {
                        block?()
                    } else {
                        for subscription: CKSubscription in iSubscriptions! {
                            self.currentDB?.delete(withSubscriptionID: subscription.subscriptionID, completionHandler: { (iSubscription: String?, iDeleteError: Error?) in
                                if iDeleteError != nil {
                                    self.reportError(iDeleteError)
                                }

                                count -= 1

                                if count == 0 {
                                    block?()
                                }
                            })
                        }
                    }
                }
            }
        }
    }


    func subscribe(_ block: (() -> Swift.Void)?) {
        if currentDB == nil {
            block?()
        } else {
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

                currentDB?.save(subscription, completionHandler: { (iSubscription: CKSubscription?, iSaveError: Error?) in
                    if iSaveError != nil {
                        controllersManager.signal(iSaveError as NSObject?, regarding: .error)

                        self.reportError(iSaveError)
                    }

                    count -= 1
                    
                    if count == 0 {
                        block?()
                    }
                })
            }
        }
    }


    func setIntoObject(_ object: ZRecord, value: NSObject?, forPropertyName: String) {
        if currentDB != nil {
            if let    record = object.record {
                let oldValue = record[forPropertyName] as? NSObject

                if oldValue != value {
                    record[forPropertyName] = value as! CKRecordValue?

                    object.recordState.insert(.needsSave)
                }
            }
        }
    }


    func getFromObject(_ object: ZRecord, valueForPropertyName: String) {
        if currentDB != nil && object.record != nil && operationsManager.isReady {
            let      predicate = NSPredicate(format: "")
            let  type: String  = className(of: object);
            let query: CKQuery = CKQuery(recordType: type, predicate: predicate)

            currentDB?.perform(query, inZoneWith: nil) { (iResults: [CKRecord]?, performanceError: Error?) in
                if performanceError != nil {
                    controllersManager.signal(performanceError as NSObject?, regarding: .error)
                } else {
                    let        record: CKRecord = (iResults?[0])!
                    object.record[valueForPropertyName] = (record as! CKRecordValue)

                    controllersManager.signal(nil, regarding: .data)
                }
            }
        }
    }
}

