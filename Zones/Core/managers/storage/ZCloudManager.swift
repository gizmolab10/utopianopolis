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


    func fetchCloudZones(_ onCompletion: Closure?) {
        container = CKContainer(identifier: cloudID)

        bookmarksManager.setup()
        travelManager   .setup()

        if let                              operation = configure(CKFetchRecordZonesOperation()) as? CKFetchRecordZonesOperation {
            operation.fetchRecordZonesCompletionBlock = { (recordZonesByZoneID, operationError) in
                self.cloudZonesByID                   = recordZonesByZoneID!

                self.resetBadgeCounter()

                onCompletion?()
            }

            operation.start()

            return
        }

        onCompletion?()
    }


    func establishRootAsHere(_ onCompletion: Closure?) {
        let recordID = CKRecordID(recordName: rootNameKey)

        self.assureRecordExists(withRecordID: recordID, storageMode: travelManager.storageMode, recordType: zoneTypeKey, onCompletion: { (iRecord: CKRecord?) -> (Void) in
            if iRecord != nil {
                travelManager.rootZone = Zone(record: iRecord, storageMode: travelManager.storageMode)
                travelManager.hereZone = travelManager.rootZone

                travelManager.rootZone?.needChildren()
                travelManager.manifest.needSave()
            }

            onCompletion?()
        })
    }


    func establishHere(_ onCompletion: Closure?) {
        let         manifestName = "\(manifestNameKey).\(travelManager.storageMode.rawValue)"
        var recordID: CKRecordID = CKRecordID(recordName: manifestName)

        assureRecordExists(withRecordID: recordID, storageMode: .mine, recordType: manifestTypeKey, onCompletion: { (iManifestRecord: CKRecord?) -> (Void) in
            if iManifestRecord != nil {
                travelManager.manifest.record = iManifestRecord

                if travelManager.manifest.here != nil {
                    recordID = (travelManager.manifest.here?.recordID)!

                    self.assureRecordExists(withRecordID: recordID, storageMode: travelManager.storageMode, recordType: zoneTypeKey, onCompletion: { (iHereRecord: CKRecord?) -> (Void) in
                        if iHereRecord == nil || iHereRecord?[zoneNameKey] == nil {
                            self.establishRootAsHere(onCompletion)
                        } else {
                            travelManager.hereZone = Zone(record: iHereRecord, storageMode: travelManager.storageMode)

                            travelManager.hereZone?.updateZoneProperties()
                            travelManager.hereZone?.needChildren()
                            travelManager.manifest.needSave()

                            onCompletion?()
                        }
                    })

                    return
                }
            }

            self.establishRootAsHere(onCompletion)
        })
    }


    func merge(_ onCompletion: Closure?) {
        if let        operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            invokeWithMode(travelManager.storageMode, block: {
                operation.recordIDs = recordIDsWithMatchingStates([.needsMerge])
            })

            if (operation.recordIDs?.count)! > 0 {

                report("merging \((operation.recordIDs?.count)!)")

                operation.completionBlock          = onCompletion
                operation.perRecordCompletionBlock = { (iRecord, iID, iError) in
                    let record = self.recordForRecordID(iID)

                    if iRecord != nil {
                        record?.mergeIntoAndTake(iRecord!)
                    } else if let error: CKError = iError as? CKError {
                        self.reportError(error)
                        record?.markForStates([.needsSave])
                    }
                }

                operation.start()
                
                return
            }
        }

        onCompletion?()
    }


    func fetchParents(_ onCompletion: Closure?) {
        let missingParents = parentIDsWithMatchingStates([.needsParent])
        let orphans        = recordIDsWithMatchingStates([.needsParent])

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

                report("fetching parents \(missingParents.count)")

                operation.start()

                return
            }
        }
        
        onCompletion?()
    }


    func fetch(_ onCompletion: Closure?) {
        if let            operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            invokeWithMode(travelManager.storageMode, block: {
                operation.recordIDs = recordIDsWithMatchingStates([.needsFetch])
            })

            if (operation.recordIDs?.count)! > 0 {

                report("fetching \((operation.recordIDs?.count)!)")

                operation.completionBlock          = onCompletion
                operation.perRecordCompletionBlock = { (iRecord, iID, iError) in
                    if let error: CKError = iError as? CKError {
                        self.reportError(error)
                    } else if let record = self.recordForRecordID(iID) {
                        record.unmarkForStates([.needsFetch])

                        record.record = iRecord
                    }
                }

                operation.start()
                
                return
            }
        }

        onCompletion?()
    }


    func royalFlush(_ onCompletion: Closure?) {
        for zone in zones.values {
            if !zone.isMarkedForStates([.needsFetch, .needsSave, .needsCreate]) {
                zone.unmarkForStates([.needsMerge])
                zone.normalizeOrdering()
                zone.updateCloudProperties()
            }
        }

        operationsManager.sync(onCompletion)
    }


    func create(_ onCompletion: Closure?) {
        if let operation = configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
            operation.recordsToSave   = recordsWithMatchingStates([.needsCreate])
            operation.completionBlock = onCompletion

            clearState(.needsCreate)

            if (operation.recordsToSave?.count)! > 0 {

                report("creating \((operation.recordsToSave?.count)!)")

                operation.start()
                
                return
            }
        }
        
        onCompletion?()
    }


    func flush(_ onCompletion: Closure?) {
        flush(travelManager.storageMode, onCompletion: onCompletion)
    }


    func flush(_ storageMode: ZStorageMode, onCompletion: Closure?) {
        if let operation = configure(CKModifyRecordsOperation(), using: storageMode) as? CKModifyRecordsOperation {
            invokeWithMode(storageMode) {
                operation.recordsToSave     =   recordsWithMatchingStates([.needsSave])
                operation.recordIDsToDelete = recordIDsWithMatchingStates([.needsDelete])

                clearStates([.needsSave, .needsDelete]) // clear BEFORE looking at manifest
            }

            if (operation.recordsToSave?.count)! > 0 || (operation.recordIDsToDelete?.count)! > 0 {

                report("saving \((operation.recordsToSave?.count)!) deleting \((operation.recordIDsToDelete?.count)!)")

                operation.completionBlock          = {
                    for identifier: CKRecordID in operation.recordIDsToDelete! {
                        var dict = self.zones
                        let zone = dict[identifier.recordName]

                        self.unregisterZone(zone)
                    }

                    let flushMine = self.detectWithMode(.mine, block: {
                        return self.recordsWithMatchingStates([.needsSave]).count > 0
                    })

                    if flushMine {
                        self.flush(.mine, onCompletion: onCompletion)
                    } else {
                        controllersManager.signal(nil, regarding: .data)
                        onCompletion?()
                    }
                }

                operation.perRecordCompletionBlock = { (iRecord, iError) in
                    if  let error:         CKError = iError as? CKError {
                        let info                   = error.errorUserInfo
                        var description:    String = info["ServerErrorDescription"] as! String

                        if  description           != "record to insert already exists" {
                            if let record          = self.recordForRecordID((iRecord?.recordID)!) {
                                record.needFetch()
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

        let flushMine = detectWithMode(.mine, block: {
            return self.recordsWithMatchingStates([.needsSave]).count > 0
        })

        if flushMine {
            flush(.mine, onCompletion: onCompletion)
        } else {
            onCompletion?()
        }
    }


    func cloudQueryUsingPredicate(_ predicate: NSPredicate, onCompletion: RecordClosure?) {
        if let operation = configure(CKQueryOperation()) as? CKQueryOperation {
            operation.query              = CKQuery(recordType: zoneTypeKey, predicate: predicate)
            operation.desiredKeys        = Zone.cloudProperties()
            operation.recordFetchedBlock = { iRecord in
                onCompletion?(iRecord)
            }

            operation.queryCompletionBlock = { (cursor, error) in
                if error != nil {
                    self.reportError(error)
                }

                onCompletion?(nil)
            }

            operation.start()
        } else {
            onCompletion?(nil)
        }
    }


    func searchFor(_ searchFor: String, onCompletion: ObjectClosure?) {
        let           predicate = NSPredicate(format: "self CONTAINS %@", searchFor)
        var records: [CKRecord] = []

        cloudQueryUsingPredicate(predicate, onCompletion: { iRecord in
            if iRecord != nil {
                records.append(iRecord!)
            } else {
                onCompletion?(records as NSObject)
            }
        })
    }


    @discardableResult func fetchChildren(_ onCompletion: Closure?) -> Bool {
        let childrenNeeded: [CKReference] = referencesWithMatchingStates([.needsChildren])
        let                noMoreChildren = childrenNeeded.count == 0

        if noMoreChildren {
            onCompletion?()
        } else {
            var parentsNeedingResort: [Zone] = []
            let                    predicate = NSPredicate(format: "parent IN %@", childrenNeeded)

            clearState(.needsChildren)
            report("fetching children of \(childrenNeeded.count)")
            cloudQueryUsingPredicate(predicate, onCompletion: { iRecord in
                if iRecord == nil { // we already received full response from cloud
                    for parent in parentsNeedingResort {
                        parent.respectOrder()
                    }

                    controllersManager.signal(nil, regarding: .data)

                    self.fetchChildren(onCompletion)
                } else {
                    var child = self.zoneForRecordID(iRecord?.recordID)

                    if child == nil {
                        child = Zone(record: iRecord, storageMode: travelManager.storageMode)
                    }

                    child?.updateZoneProperties()
                    child?.needChildren()

                    if let parent = child?.parentZone {
                        if parent != child {
                            parent.addChild(child!)

                            if !parentsNeedingResort.contains(parent) {
                                parentsNeedingResort.append(parent)
                            }
                        }

                        return
                    }

                    self.reportError(child?.zoneName)
                }
            })
        }

        return noMoreChildren
    }


    func receivedUpdateFor(_ recordID: CKRecordID) {
        resetBadgeCounter()
        assureRecordExists(withRecordID: recordID, storageMode: travelManager.storageMode, recordType: zoneTypeKey, onCompletion: { iRecord in
            var         record = self.recordForRecordID(iRecord?.recordID)
            var parent:  Zone? = nil

            if  record == nil {
                record = Zone(record: iRecord, storageMode: travelManager.storageMode) // it could be a ZManifest record, TODO: detect and correct
            } else {
                record?.record = iRecord
                parent         = (record as? Zone)?.parentZone
            }

            record?.needChildren()

            self.dispatchAsyncInForeground {

                controllersManager.signal(parent, regarding: .data)

                operationsManager.getChildren {
                    controllersManager.signal(parent, regarding: .data)
                }
            }
        })
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


    func unsubscribe(_ block: Closure?) {
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


    func subscribe(_ block: Closure?) {
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

                    object.maybeNeedMerge()
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

