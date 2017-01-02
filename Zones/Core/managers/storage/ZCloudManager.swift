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
    var cloudZonesByID = [CKRecordZoneID : CKRecordZone] ()
    var        container: CKContainer!
    var        currentDB: CKDatabase? { get { return databaseForMode(travelManager.storageMode) } }


    func databaseForMode(_ mode: ZStorageMode) -> CKDatabase? {
        switch mode {
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


    // MARK:- push to cloud
    // MARK:-


    func royalFlush(_ onCompletion: @escaping Closure) {
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

                toConsole("creating \((operation.recordsToSave?.count)!)")

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
                operation.recordsToSave = recordsWithMatchingStates([.needsSave])

                clearStates([.needsSave]) // clear BEFORE looking at manifest
            }

            if (operation.recordsToSave?.count)! > 0 {

                toConsole("saving \((operation.recordsToSave?.count)!)")

                operation.completionBlock          = {
                    for record: CKRecord in operation.recordsToSave! {
                        var dict = self.zones

                        if let zone = dict[record.recordID.recordName], zone.isDeleted {
                            self.unregisterZone(zone)
                        }
                    }

                    let flushMine = self.detectWithMode(.mine, block: {
                        return self.recordsWithMatchingStates([.needsSave]).count > 0
                    })

                    if flushMine {
                        self.flush(.mine, onCompletion: onCompletion)
                    } else {
                        self.signalFor(nil, regarding: .data)
                        onCompletion?()
                    }
                }

                operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iError: Error?) in
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


    // MARK:- receive from cloud
    // MARK:-


    func receivedUpdateFor(_ recordID: CKRecordID) {
        resetBadgeCounter()
        assureRecordExists(withRecordID: recordID, storageMode: travelManager.storageMode, recordType: zoneTypeKey, onCompletion: { iRecord in
            let   zone = self.zoneForRecord(iRecord!)
            let parent = zone.parentZone

            if  zone.showChildren {
                self.dispatchAsyncInForeground {
                    self.signalFor(parent, regarding: .redraw)

                    operationsManager.children(false) {
                        self.signalFor(parent, regarding: .redraw)
                    }
                }
            }
        })
    }


    // MARK:- request from cloud
    // MARK:-


    func establishHere(_ onCompletion: Closure?) {
        let         manifestName = "\(manifestNameKey).\(travelManager.storageMode.rawValue)"
        var recordID: CKRecordID = CKRecordID(recordName: manifestName)

        assureRecordExists(withRecordID: recordID, storageMode: .mine, recordType: manifestTypeKey, onCompletion: { (iManifestRecord: CKRecord?) in
            if iManifestRecord != nil {
                travelManager.manifest.record = iManifestRecord

                if travelManager.manifest.here != nil {
                    recordID = (travelManager.manifest.here?.recordID)!

                    self.assureRecordExists(withRecordID: recordID, storageMode: travelManager.storageMode, recordType: zoneTypeKey, onCompletion: { (iHereRecord: CKRecord?) in
                        if iHereRecord == nil || iHereRecord?[zoneNameKey] == nil {
                            self.establishRootAsHere(onCompletion)
                        } else {
                            let               here = self.zoneForRecord(iHereRecord!)
                            travelManager.hereZone = here

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


    func establishRootAsHere(_ onCompletion: Closure?) {
        let recordID = CKRecordID(recordName: rootNameKey)

        self.assureRecordExists(withRecordID: recordID, storageMode: travelManager.storageMode, recordType: zoneTypeKey, onCompletion: { (iRecord: CKRecord?) in
            if iRecord != nil {
                let               root = self.zoneForRecord(iRecord!)
                travelManager.hereZone = root
                travelManager.rootZone = root
                root.level             = 0

                travelManager.manifest.needSave()
            }

            onCompletion?()
        })
    }
    

    func assureRecordExists(withRecordID recordID: CKRecordID, storageMode: ZStorageMode, recordType: String, onCompletion: @escaping RecordClosure) {
        let database = databaseForMode(storageMode)

        if database == nil {
            onCompletion(nil)
        } else {
            database?.fetch(withRecordID: recordID) { (fetched: CKRecord?, fetchError: Error?) in
                if (fetchError == nil) {
                    if let zone = self.zoneForRecordID(fetched?.recordID), zone.zoneName == nil {
                        zone.record = fetched
                    }

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


    func predicateFrom(_ searchString: String) -> NSPredicate {
        let    tokens = searchString.components(separatedBy: " ")
        let separator = " AND "
        var    suffix = ""

        for token in tokens {
            if token != "" {
                suffix = String(format: "%@%@SELF CONTAINS \"%@\"", suffix, separator, token)
            }
        }

        let format = String(format: "zoneState < %d AND zoneLink = \"\"%@", ZoneState.IsDeleted.rawValue, suffix)

        return NSPredicate(format: format)
    }


    func searchFor(_ searchFor: String, onCompletion: ObjectClosure?) {
        let predicate = predicateFrom(searchFor)
        var   records = [CKRecord] ()

        cloudQueryUsingPredicate(predicate, onCompletion: { iRecord in
            if iRecord != nil {
                records.append(iRecord!)
            } else {
                onCompletion?(records as NSObject)
            }
        })
    }


    @discardableResult func fetchChildren(_ onCompletion: Closure?) -> Bool {
        let childrenNeeded = referencesWithMatchingStates([.needsChildren])
        let noMoreChildren = childrenNeeded.count == 0

        if noMoreChildren {
            onCompletion?()
        } else {
            var parentsNeedingResort = [Zone] ()
            let            predicate = NSPredicate(format: "zoneState < %d AND parent IN %@", ZoneState.IsDeleted.rawValue, childrenNeeded)
            let                zones = zoneNamesWithMatchingStates([.needsChildren])

            clearState(.needsChildren)
            toConsole("fetching children of \(zones)")
            cloudQueryUsingPredicate(predicate, onCompletion: { (iRecord: CKRecord?) in
                if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                    for parent in parentsNeedingResort {
                        parent.respectOrder()
                    }

                    self.signalFor(nil, regarding: .redraw)

                    self.fetchChildren(onCompletion) // recurse: try another fetch
                } else {
                    let child = self.zoneForRecord(iRecord!)

                    if recursivelyExpand {
                        child.needChildren()
                    }

                    if let parent = child.parentZone {
                        if parent != child {
                            parent.addChild(child)

                            if !parentsNeedingResort.contains(parent) {
                                parentsNeedingResort.append(parent)
                            }
                        }
                        
                        return
                    }
                    
                    self.reportError(child.zoneName)
                }
            })
        }
        
        return noMoreChildren
    }


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


    func merge(_ onCompletion: Closure?) {
        let recordIDs = recordIDsWithMatchingStates([.needsMerge])

        if  recordIDs.count > 0, let operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            toConsole("merging \(recordIDs.count)")

            operation.recordIDs                = recordIDs
            operation.completionBlock          = onCompletion
            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                if let record = self.recordForRecordID(iID) {
                    record.mergeIntoAndTake(iRecord!)
                } else if let error: CKError = iError as? CKError {
                    self.reportError(error)
                }
            }

            operation.start()
        } else {
            onCompletion?()
        }
    }


    func fetchParents(_ onCompletion: Closure?) {
        let missingParents = parentIDsWithMatchingStates([.needsParent])
        let orphans        = recordIDsWithMatchingStates([.needsParent])

        if missingParents.count > 0 {
            if let operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
                operation.recordIDs       = missingParents
                operation.completionBlock = onCompletion
                operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                    var parent = self.zoneForRecordID(iID)

                    if parent != nil && iRecord != nil {
                        parent?.mergeIntoAndTake(iRecord!)
                    } else if let error: CKError = iError as? CKError {
                        self.reportError(error)
                    } else {
                        parent = self.zoneForRecord(iRecord!)

                        for orphan in orphans {
                            if let child = self.zoneForRecordID(orphan), let parentID = child.parentZone?.record.recordID, parentID == parent?.record.recordID {
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
        invokeWithMode(travelManager.storageMode) {
            let    needed = referencesWithMatchingStates([.needsFetch])
            let predicate = NSPredicate(format: "zoneState < %d AND creatorUserRecordID IN %@", ZoneState.IsDeleted.rawValue, needed)

            self.toConsole("fetching \(needed.count)")

            self.cloudQueryUsingPredicate(predicate, onCompletion: { iRecord in
                if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                    onCompletion?()
                } else if let record = self.recordForRecordID(iRecord?.recordID) {
                    record.unmarkForStates([.needsFetch])

                    record.record = iRecord
                }
            })
        }

        onCompletion?()
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
                        self.signalFor(iSaveError as NSObject?, regarding: .error)
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
            let      predicate = NSPredicate(value: true)
            let  type: String  = NSStringFromClass(type(of: object)) as String
            let query: CKQuery = CKQuery(recordType: type, predicate: predicate)

            currentDB?.perform(query, inZoneWith: nil) { (iResults: [CKRecord]?, performanceError: Error?) in
                if performanceError != nil {
                    self.signalFor(performanceError as NSObject?, regarding: .error)
                } else {
                    let        record: CKRecord = (iResults?[0])!
                    object.record[valueForPropertyName] = (record as! CKRecordValue)

                    self.signalFor(nil, regarding: .data)
                }
            }
        }
    }
}

