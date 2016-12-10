//
//  ZCloudManager.swift
//  Zones
//
//  Created by Jonathan Sand on 9/18/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZCloudManager: ZRecordsManager {
    var      container:                    CKContainer!
    var cloudZonesByID: [CKRecordZoneID : CKRecordZone] = [:]
    var      currentDB:                     CKDatabase? { get { return databaseForMode(travelManager.storageMode) } }


    func databaseForMode(_ mode: ZStorageMode) -> CKDatabase? {
        switch (mode) {
        case .everyone: return container.publicCloudDatabase
        case .group:    return container.sharedCloudDatabase
        case .mine:     return container.privateCloudDatabase
        default:        return nil
        }
    }


    func configure(_ operation: CKDatabaseOperation, using mode: ZStorageMode) -> CKDatabaseOperation? {
        if let database = databaseForMode(mode) {
            operation.qualityOfService = .background
            operation.container        = container
            operation.database         = database

            return operation
        }

        return nil
    }


    func configure(_ operation: CKDatabaseOperation) -> CKDatabaseOperation? {
        return configure(operation, using: travelManager.storageMode)
    }


    // MARK:- operations
    // MARK:-


    func fetchCloudZones(_ onCompletion: (() -> Swift.Void)?) {
        container = CKContainer(identifier: cloudID)

        bookmarksManager.setup()
        travelManager   .setup()

        if let                              operation = configure(CKFetchRecordZonesOperation()) as? CKFetchRecordZonesOperation {
            operation.fetchRecordZonesCompletionBlock = { (recordZonesByZoneID, operationError) -> Swift.Void in
                self.cloudZonesByID                   = recordZonesByZoneID!

                self.resetBadgeCounter()

                onCompletion?()
            }

            operation.start()

            return
        }

        onCompletion?()
    }


    func establishRoot(_ onCompletion: (() -> Swift.Void)?) {
        let recordID = CKRecordID(recordName: rootNameKey)

        self.assureRecordExists(withRecordID: recordID, storageMode: travelManager.storageMode, recordType: zoneTypeKey, onCompletion: { (iRecord: CKRecord?) -> (Void) in
            if iRecord != nil {
                travelManager.rootZone = Zone(record: iRecord, storageMode: travelManager.storageMode)

                travelManager.rootZone?.needChildren()

                if travelManager.manifest.here == nil {
                    travelManager.hereZone = travelManager.rootZone
                    travelManager.manifest.needSave()
                }
            }

            onCompletion?()
        })
    }


    func establishHere(_ onCompletion: (() -> Swift.Void)?) {
        if travelManager.storageMode == .bookmarks {
            travelManager.hereZone   = bookmarksManager.rootZone
        } else if let here = travelManager.hereZone, here.record != nil {
            here.needChildren()
            here.needFetch()
        } else {
            let         manifestName = "\(manifestNameKey).\(travelManager.storageMode.rawValue)"
            var recordID: CKRecordID = CKRecordID(recordName: manifestName)

            assureRecordExists(withRecordID: recordID, storageMode: .mine, recordType: manifestTypeKey, onCompletion: { (iManifestRecord: CKRecord?) -> (Void) in
                if iManifestRecord != nil {
                    travelManager.manifest.record = iManifestRecord

                    if travelManager.manifest.here != nil {
                        recordID = (travelManager.manifest.here?.recordID)!

                        self.assureRecordExists(withRecordID: recordID, storageMode: travelManager.storageMode, recordType: zoneTypeKey, onCompletion: { (iHereRecord: CKRecord?) -> (Void) in
                            if iHereRecord != nil {
                                travelManager.hereZone = Zone(record: iHereRecord, storageMode: travelManager.storageMode)

                                travelManager.hereZone?.needChildren()
                                travelManager.manifest.needSave()
                            }

                            onCompletion?()
                        })

                        return
                    }
                }

                self.establishRoot(onCompletion)
            })

            return
        }

        onCompletion?()
    }


    func merge(_ onCompletion: (() -> Swift.Void)?) {
        if let        operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            operation.recordIDs = recordIDsMatching([.needsMerge])

            if (operation.recordIDs?.count)! > 0 {

                reportError("merging \((operation.recordIDs?.count)!)")

                operation.completionBlock          = onCompletion
                operation.perRecordCompletionBlock = { (iRecord, iID, iError) in
                    let zone = self.zoneForRecordID(iID)

                    if iRecord != nil {
                        zone?.mergeIntoAndTake(iRecord!)
                    } else if let error: CKError = iError as? CKError {
                        self.reportError(error)

                        zone?.needSave()
                    }
                }

                operation.start()
                
                return
            }
        }

        onCompletion?()
    }


    func fetchParents(_ onCompletion: (() -> Swift.Void)?) {
        let missingParents = parentIDsMatching([.needsParent])
        let orphans        = recordIDsMatching([.needsParent])

        if missingParents.count > 0 {
            if let operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
                operation.recordIDs       = missingParents
                operation.completionBlock = onCompletion
                operation.perRecordCompletionBlock = { (iRecord, iRecordID, iError) in
                    var parent = self.zoneForRecordID(iRecordID)

                    if parent != nil && iRecord != nil {
                        parent?.mergeIntoAndTake(iRecord!)
                    } else if let error: CKError = iError as? CKError {
                        self.reportError(error)

                        parent?.needSave()
                    } else {
                        parent = Zone(record: iRecord, storageMode: travelManager.storageMode)

                        parent?.register()
                        parent?.needChildren()

                        for orphan in orphans {
                            if iRecordID?.recordName == orphan.recordName, let child = self.zoneForRecordID(orphan) {
                                parent?.children.append(child)
                            }
                        }


                    }
                }

                clearState(.needsParent)

                reportError("fetching parents \(missingParents.count)")

                operation.start()

                return
            }
        }
        
        onCompletion?()
    }


    func fetch(_ onCompletion: (() -> Swift.Void)?) {
        if let        operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            operation.recordIDs = recordIDsMatching([.needsFetch])

            if (operation.recordIDs?.count)! > 0 {

                reportError("fetching \((operation.recordIDs?.count)!)")

                operation.completionBlock          = onCompletion
                operation.perRecordCompletionBlock = { (iRecord, iID, iError) in
                    if let error: CKError = iError as? CKError {
                        self.reportError(error)
                    } else if let zone: Zone = self.zoneForRecordID(iID) {
                        self.removeRecord(zone, forState: .needsFetch)

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
        for zone in zones.values {
            if !hasRecord(zone, forState: .needsFetch) && !hasRecord(zone, forState: .needsSave) && !hasRecord(zone, forState: .needsCreate) {
                removeRecord(zone, forState: .needsMerge)
                zone.normalizeOrdering()
                zone.updateCloudProperties()
            }
        }

        operationsManager.sync(onCompletion)
    }


    func create(_ onCompletion: (() -> Swift.Void)?) {
        if let operation = configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
            operation.recordsToSave   = recordsMatching([.needsCreate])
            operation.completionBlock = onCompletion

            clearState(.needsCreate)

            if (operation.recordsToSave?.count)! > 0 {

                reportError("creating \((operation.recordsToSave?.count)!)")

                operation.start()
                
                return
            }
        }
        
        onCompletion?()
    }


    func flush(_ onCompletion: (() -> Swift.Void)?) {
        flush(travelManager.storageMode, onCompletion: onCompletion)
    }


    func flush(_ storageMode: ZStorageMode, onCompletion: (() -> Swift.Void)?) {
        if let operation = configure(CKModifyRecordsOperation(), using: storageMode) as? CKModifyRecordsOperation {
            operation.recordsToSave     =   recordsMatching([.needsSave])
            operation.recordIDsToDelete = recordIDsMatching([.needsDelete])

            clearStates([.needsSave, .needsDelete])

            if storageMode == .everyone {

                // if records to save contains a manifest object and travelManager's storage mode is .everyone
                // remove it and set it aside for saving in a separate operation to save into mode .mine

                if let record = travelManager.manifest.record, let index = operation.recordsToSave?.index(of: record) {
                    operation.recordsToSave?.remove(at: index)
                    travelManager.manifest.needSave()
                }
            }

            if (operation.recordsToSave?.count)! > 0 || (operation.recordIDsToDelete?.count)! > 0 {

                reportError("saving \((operation.recordsToSave?.count)!) deleting \((operation.recordIDsToDelete?.count)!)")

                operation.completionBlock          = {
                    for identifier: CKRecordID in operation.recordIDsToDelete! {
                        let zone = self.zones[identifier]

                        zone?.orphan()
                        self.unregisterZone(zone)
                    }

                    if self.recordsMatching([.needsSave]).count > 0 {
                        self.flush(.mine, onCompletion: onCompletion)
                    } else {
                        controllersManager.signal(nil, regarding: .data)
                        onCompletion?()
                    }
                }

                operation.perRecordCompletionBlock = { (iRecord, iError) -> Swift.Void in
                    if  let error:         CKError = iError as? CKError {
                        let info                   = error.errorUserInfo
                        var description:    String = info["ServerErrorDescription"] as! String

                        if  description           != "record to insert already exists" {
                            if let zone            = self.zoneForRecordID((iRecord?.recordID)!) {
                                zone.needFetch()
                            }

                            if let name            = iRecord?["zoneName"] as! String? {
                                description        = "\(description): \(name)"
                            }

                            self.reportError(description)
                        }
                    }
                }
                
                operation.start()
                
                return
            }
        }

        if self.recordsMatching([.needsSave]).count > 0 {
            self.flush(.mine, onCompletion: onCompletion)
        } else {
            onCompletion?()
        }
    }


    @discardableResult func fetchChildren(_ onCompletion: (() -> Swift.Void)?) -> Bool {
        let childrenNeeded: [CKReference] = referencesMatching([.needsChildren])

        clearState(.needsChildren)

        if childrenNeeded.count > 0, let operation = configure(CKQueryOperation()) as? CKQueryOperation {

            reportError("fetching children of \(childrenNeeded.count)")

            var parentsNeedingResort: [Zone] = []
            let                    predicate = NSPredicate(format: "parent IN %@", childrenNeeded)
            operation.query                  = CKQuery(recordType: zoneTypeKey, predicate: predicate)
            operation.desiredKeys            = Zone.cloudProperties()
            operation.recordFetchedBlock     = { iRecord -> Swift.Void in
                var child = self.zoneForRecordID(iRecord.recordID)

                if child == nil {
                    child = Zone(record: iRecord, storageMode: travelManager.storageMode)
                }

                child?.updateZoneProperties()
                child?.needChildren()

                if let parent = child?.parentZone {
                    if parent != child {
                        parent.appendChild(child!)

                        if !parentsNeedingResort.contains(parent) {
                            parentsNeedingResort.append(parent)
                        }
                    }

                    return
                }

                self.reportError(child?.zoneName)
            }

            operation.queryCompletionBlock = { (cursor, error) -> Swift.Void in
                if error != nil {
                    self.reportError(error)
                }

                for parent in parentsNeedingResort {
                    parent.respectOrder()
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


    func receivedUpdateFor(_ recordID: CKRecordID) {
        resetBadgeCounter()
        assureRecordExists(withRecordID: recordID, storageMode: travelManager.storageMode, recordType: zoneTypeKey, onCompletion: { (iRecord: CKRecord) -> (Void) in
            var zone = self.zoneForRecordID(iRecord.recordID)

            if  zone != nil {
                zone?.record = iRecord
            } else {
                zone = Zone(record: iRecord, storageMode: travelManager.storageMode)
            }

            zone?.needChildren()

            self.dispatchAsyncInForeground {
                controllersManager.signal(zone?.parentZone, regarding: .data)

                operationsManager.getChildren {
                    controllersManager.signal(zone?.parentZone, regarding: .data)
                }
            }
        } as! RecordClosure)
    }


    func assureRecordExists(withRecordID recordID: CKRecordID, storageMode: ZStorageMode, recordType: String, onCompletion: @escaping RecordClosure) {
        let database = databaseForMode(storageMode)

        if database == nil {
            onCompletion(nil)
        } else {
            database?.fetch(withRecordID: recordID) { (fetched: CKRecord?, fetchError: Error?) in
                if (fetchError == nil) {
                    onCompletion(fetched!)
                } else {
                    let created: CKRecord = CKRecord(recordType: recordType, recordID: recordID)

                    database?.save(created, completionHandler: { (saved: CKRecord?, saveError: Error?) in
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
            let classNames = [zoneTypeKey, manifestTypeKey] //, "ZTrait", "ZAction"]
            var      count = classNames.count

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

                    if !hasRecord   (object, forState: .needsCreate) {
                        removeRecord(object, forState: .needsMerge)
                    }
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

