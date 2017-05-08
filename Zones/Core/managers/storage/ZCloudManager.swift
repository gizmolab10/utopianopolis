//
//  ZCloudManager.swift
//  Zones
//
//  Created by Jonathan Sand on 9/18/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


class ZCloudManager: ZRecordsManager {
    var cloudZonesByID = [CKRecordZoneID : CKRecordZone] ()
    var      container:   CKContainer?


    func databaseForMode(_ mode: ZStorageMode) -> CKDatabase? {
        switch mode {
        case .everyone: return container?.publicCloudDatabase
        case .shared:   return container?.sharedCloudDatabase
        case .mine:     return container?.privateCloudDatabase
        default:        return nil
        }
    }


    func configure(_ operation: CKDatabaseOperation, using mode: ZStorageMode) -> CKDatabaseOperation? {
        if  let               database = databaseForMode(mode) {
            operation.qualityOfService = .background
            operation.container        = container
            operation.database         = database

            return operation
        }

        return nil
    }


    // MARK:- receive from cloud
    // MARK:-


    func receivedUpdateFor(_ recordID: CKRecordID) {
        resetBadgeCounter()
        assureRecordExists(withRecordID: recordID, storageMode: gStorageMode, recordType: zoneTypeKey) { iRecord in
            if iRecord != nil { // NEED TODO storage mode, i.e., the database
                // get from the record id's cloud zone
                let   zone = self.zoneForRecord(iRecord!, in: gStorageMode)
                let parent = zone.parentZone

                if  zone.showChildren {
                    self.dispatchAsyncInForeground {
                        self.signalFor(parent, regarding: .redraw)

                        gOperationsManager.children() {
                            self.signalFor(parent, regarding: .redraw)
                        }
                    }
                }
            }
        }
    }


    // MARK:- push to cloud
    // MARK:-


    func create(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        if  let           operation = configure(CKModifyRecordsOperation(), using: storageMode) as? CKModifyRecordsOperation {
            operation.recordsToSave = recordsWithMatchingStates([.needsCreate], in: storageMode)

            clearState(.needsCreate, in: storageMode)

            if let count = operation.recordsToSave?.count, count > 0 {
                operation.completionBlock = { onCompletion?(0) }

                note("creating \(count)")

                operation.start()

                return
            }
        }

        onCompletion?(0)
    }


    func flush(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        if  let           operation = configure(CKModifyRecordsOperation(), using: storageMode) as? CKModifyRecordsOperation {
            operation.recordsToSave = recordsWithMatchingStates([.needsSave], in: storageMode)

            clearStates([.needsSave], in: storageMode) // clear BEFORE looking at manifest

            if operation.recordsToSave!.count > 0 {

                performance("SAVE \((operation.recordsToSave?.count)!)      \(stringForRecords(operation.recordsToSave))")

                operation.completionBlock          = {

                    // deal with saved records marked as deleted
                    for record: CKRecord in operation.recordsToSave! {
                        if let zone = self.zoneForRecordID(record.recordID, in: storageMode), zone.isDeleted {
                            self.unregisterZone(zone)
                        }
                    }

                    onCompletion?(0)
                }

                operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iError: Error?) in

                    // mark failed records as needing fetch
                    if  let error:      CKError = iError as? CKError {
                        let info                = error.errorUserInfo
                        var description: String = info["CKErrorDescription"] as! String

                        if  description        != "record to insert already exists" {
                            if  let      record = self.recordForCKRecord(iRecord, in: storageMode) {
                                record.maybeNeedMerge()
                            }

                            if  let        name = iRecord?["zoneName"] as! String? {
                                description     = "\(description): \(name)"
                            }

                            self.performance("SAVE ==> \(storageMode) \(description)")
                        }
                    }
                }

                operation.start()

                return
            }
        }

        onCompletion?(0)
    }


    func emptyTrash(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let   predicate = NSPredicate(format: "zoneState <= %d", ZoneState.IsDeleted.rawValue)
        var toBeDeleted = [CKRecordID] ()

        self.queryWith(predicate, storageMode: storageMode) { (iRecord: CKRecord?) in
            if iRecord != nil {
                self.performance("DELETE \(String(describing: iRecord![zoneNameKey]))")
                toBeDeleted.append((iRecord?.recordID)!)

            } else { // iRecord == nil means: end of response to this particular query

                if (toBeDeleted.count) > 0, let operation = self.configure(CKModifyRecordsOperation(), using: storageMode) as? CKModifyRecordsOperation {
                    operation.completionBlock   = { onCompletion?(0) }
                    operation.recordIDsToDelete = toBeDeleted   // delete them

                    operation.start()
                } else {
                    onCompletion?(0)
                }
            }
        }
    }


    // MARK:- request from cloud
    // MARK:-


    func assureRecordExists(withRecordID recordID: CKRecordID, storageMode: ZStorageMode, recordType: String, onCompletion: @escaping RecordClosure) {
        let database = databaseForMode(storageMode)

        if database == nil {
            onCompletion(nil)
        } else {
            database?.fetch(withRecordID: recordID) { (fetched: CKRecord?, fetchError: Error?) in
                if (fetchError == nil) {
                    if let zone = self.zoneForRecordID(fetched?.recordID, in: storageMode), zone.zoneName == nil {
                        zone.record = fetched
                    }

                    onCompletion(fetched!)
                } else {
                    let created: CKRecord = CKRecord(recordType: recordType, recordID: recordID)

                    database?.save(created) { (saved: CKRecord?, saveError: Error?) in
                        if (saveError != nil) {
                            onCompletion(nil)
                        } else {
                            onCompletion(saved!)
                            gfileManager.save(to: storageMode)
                        }
                    }
                }
            }
        }
    }


    func queryWith(_ predicate: NSPredicate, storageMode: ZStorageMode, onCompletion: RecordClosure?) {
        if  let                operation = configure(CKQueryOperation(), using: storageMode) as? CKQueryOperation {
            operation             .query = CKQuery(recordType: zoneTypeKey, predicate: predicate)
            operation       .desiredKeys = Zone.cloudProperties()
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


    func searchPredicateFrom(_ searchString: String) -> NSPredicate {
        let    tokens = searchString.components(separatedBy: " ")
        let separator = " AND "
        var    suffix = ""

        for token in tokens {
            if token != "" {
                suffix = String(format: "%@%@SELF CONTAINS \"%@\"", suffix, separator, token)
            }
        }

        let format = String(format: "zoneState < %d%@", ZoneState.IsFavorite.rawValue, suffix)

        return NSPredicate(format: format)
    }


    func searchFor(_ searchFor: String, storageMode: ZStorageMode, onCompletion: ObjectClosure?) {
        let predicate = searchPredicateFrom(searchFor)
        var   records = [CKRecord] ()

        queryWith(predicate, storageMode: storageMode) { iRecord in
            if iRecord != nil {
                records.append(iRecord!)
            } else {
                onCompletion?(records as NSObject)
            }
        }
    }


    func merge(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let recordIDs = recordIDsWithMatchingStates([.needsMerge], in: storageMode)

        if  recordIDs.count > 0, let operation = configure(CKFetchRecordsOperation(), using: storageMode) as? CKFetchRecordsOperation {
            self.performance("MERGE       \(stringForRecordIDs(recordIDs, in: storageMode))")

            operation.recordIDs                = recordIDs
            operation.completionBlock          = { onCompletion?(0) }
            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                if  let record = self.recordForRecordID(iID, in: storageMode) {
                    let   name = record.record[zoneNameKey] as? String ?? "---"

                    if let error: CKError = iError as? CKError {
                        self.reportError("MERGE ==> \(storageMode) \(error) \(name)")
                    } else {
                        record.mergeIntoAndTake(iRecord!)
                    }
                }

                self.clearStatesForRecordID(iID, forStates:[.needsMerge], in: storageMode)
            }

            operation.start()
        } else {
            onCompletion?(0)
        }
    }


    func undelete(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let predicate = NSPredicate(format: "zoneState >= %d", ZoneState.IsDeleted.rawValue) // "parent = nil")

        self.queryWith(predicate, storageMode: storageMode) { (iRecord: CKRecord?) in
            if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                onCompletion?(0)
            } else {
                let            root = gTravelManager.rootZone(for: storageMode)
                let         deleted = self.recordForCKRecord(iRecord, in: storageMode) as? Zone ?? Zone(record: iRecord, storageMode: storageMode)
                deleted  .isDeleted = false

                if  deleted.parent != nil {
                    deleted.needParent()
                } else {
                    deleted.parentZone = root

                    root.needFetch()
                }

                deleted.maybeNeedMerge()
                deleted.updateCloudProperties()
            }
        }
    }


    // MARK:- fetch
    // MARK:-


    func fetch(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let needed = referencesWithMatchingStates([.needsFetch], in: storageMode)

        if  needed.count == 0 {
            onCompletion?(0)
        } else {
            let predicate = NSPredicate(format: "zoneState < %d AND recordID IN %@", ZoneState.IsFavorite.rawValue, needed)

            performance("FETCH       \(stringForReferences(needed, in: storageMode))")

            self.queryWith(predicate, storageMode: storageMode) { (iRecord: CKRecord?) in
                if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                    onCompletion?(0)
                } else {
                    if let record = self.recordForCKRecord(iRecord, in: storageMode) {
                        record.unmarkForStates([.needsFetch])    // deferred to make sure fetch worked before clearing fetch flag

                        record.record = iRecord

                        if let zone = record as? Zone {
                            zone.incrementProgenyCount(by: 0)
                            zone.updateLevel()
                        }
                    }
                }
            }
        }
    }


    func fetchFavorites(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let predicate = NSPredicate(format: "zoneState >= %d AND zoneState < %d", ZoneState.IsFavorite.rawValue, ZoneState.IsDeleted.rawValue)

        self.queryWith(predicate, storageMode: storageMode) { (iRecord: CKRecord?) in
            if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                gFavoritesManager.update()
                gFavoritesManager.favoritesRootZone.respectOrder()
                onCompletion?(0)
            } else {
                let        favorite = Zone(record: iRecord, storageMode: storageMode)
                let            root = gFavoritesManager.favoritesRootZone
                favorite.parentZone = root
                var           found = false

                // avoid adding a duplicate (which was created by a bug)

                if  let        name = favorite.zoneName {
                    for zone: Zone in root.children {
                        if  let link  = favorite.zoneLink {
                            if  link == zone.zoneLink {
                                found = true

                                break
                            }
                        }

                        if name == zone.zoneName {
                            found   = true

                            break
                        }
                    }
                }

                if !found {
                    root.addChild(favorite)
                } else {
                    favorite.isDeleted = true
                    
                    favorite.needSave()
                }
            }
        }
    }


    func fetchManifest(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        gFavoritesManager.setup()

        let         manifestName = manifestNameForMode(storageMode)
        let recordID: CKRecordID = CKRecordID(recordName: manifestName)

        assureRecordExists(withRecordID: recordID, storageMode: .mine, recordType: manifestTypeKey) { (iManifestRecord: CKRecord?) in
            if  iManifestRecord != nil {
                let     manifest = gTravelManager.manifest(for: storageMode)
                manifest.record  = iManifestRecord
            }

            onCompletion?(0)
        }
    }


    func fetchToRoot(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        var getParentOf: ZoneClosure? = nil

        getParentOf = { iZone in
            iZone.needParent()

            self.fetchParents(storageMode) { iResult in
                if iResult == 0 { // zero means no more parents to fetch for this batch
                    if  let parent = iZone.parentZone {
                        getParentOf?(parent)    // continue
                    } else {
                        if let name = iZone.record?.recordID.recordName, name == rootNameKey {
                            gTravelManager.setRoot(iZone, for: storageMode) // got root
                            iZone.incrementProgenyCount(by: 0)
                        }

                        onCompletion?(0)
                    }
                }
            }
        }
        
        let manifest = gTravelManager.manifest(for: storageMode)
        let     here = manifest.hereZone

        getParentOf?(here)
    }


    func fetchParents(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let missingParents = parentIDsWithMatchingStates([.needsParent], in: storageMode)
        let        orphans = recordIDsWithMatchingStates([.needsParent], in: storageMode)

        if  missingParents.count > 0, let operation = configure(CKFetchRecordsOperation(), using: storageMode) as? CKFetchRecordsOperation {
            operation.recordIDs       = missingParents
            operation.completionBlock = { onCompletion?(0) }
            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                var parent = self.zoneForRecordID(iID, in: storageMode)

                if parent != nil && iRecord != nil {
                    parent?.mergeIntoAndTake(iRecord!) // BROKEN: likely this does not do what's needed here
                } else if let error: CKError = iError as? CKError {
                    self.reportError(error)
                } else {
                    parent = self.zoneForRecord(iRecord!, in: storageMode)

                    for orphan in orphans {
                        if let child = self.zoneForRecordID(orphan, in: storageMode), let parentID = child.parentZone?.record.recordID, parentID == parent?.record.recordID {
                            parent?.children.append(child)
                        }
                    }
                }

                if parent != nil {
                    parent?.updateLevel()
                }
            }

            performance("PARENTS of  \(stringForRecordIDs(missingParents, in: storageMode))")
            clearState(.needsParent, in: storageMode)
            operation.start()
        } else {
            onCompletion?(0)
        }
    }


    func fetchChildren(_ storageMode: ZStorageMode, _ recursiveGoal: Int? = nil, _ onCompletion: IntegerClosure?) {
        let childrenNeeded = referencesWithMatchingStates([.needsChildren], in: storageMode)

        if childrenNeeded.count == 0 {
            onCompletion?(0)
        } else {
            var parentsNeedingResort = [Zone] ()
            let            predicate = NSPredicate(format: "zoneState < %d AND parent IN %@", ZoneState.IsFavorite.rawValue, childrenNeeded)

            clearState(.needsChildren, in: storageMode)
            performance("CHILDREN of \(stringForReferences(childrenNeeded, in: storageMode))")
            queryWith(predicate, storageMode: storageMode) { (iRecord: CKRecord?) in
                if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                    for parent in parentsNeedingResort {
                        parent.respectOrder()
                        parent.updateLevel()
                    }

                    self.fetchChildren(storageMode, recursiveGoal, onCompletion) // recurse to grab children of received children
                } else {
                    let child = self.zoneForRecord(iRecord!, in: storageMode)

                    if !child.isDeleted {
                        if recursiveGoal != nil {
                            if recursiveGoal! < 0 {
                                child.needChildren()
                            } else if recursiveGoal! > child.level {
                                child.maybeNeedChildren()
                            }
                        }

                        if let parent  = child.parentZone {
                            if parent != child && !parent.children.contains(child) {
                                parent.addChild(child)
                                child.incrementProgenyCount(by: 0)

                                if !parentsNeedingResort.contains(parent) {
                                    parentsNeedingResort.append(parent)
                                }
                            }
                        } else {
                            self.performance("CHILD \(child.zoneName ?? "---"))")
                        }
                    }
                }
            }
        }
    }


    func fetchCloudZones(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        container = CKContainer(identifier: cloudID)

        if let                              operation = configure(CKFetchRecordZonesOperation(), using: storageMode) as? CKFetchRecordZonesOperation {
            onCompletion?(1)
            operation.fetchRecordZonesCompletionBlock = { (recordZonesByZoneID, operationError) in
                self.cloudZonesByID                   = recordZonesByZoneID!

                self.resetBadgeCounter()

                onCompletion?(0)
            }

            operation.start()
        } else {
            onCompletion?(0)
        }
    }


    func establishHere(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let manifest = gTravelManager.manifest(for: storageMode)

        if manifest.here == nil {
            establishRoot(storageMode, onCompletion)
        } else {
            let recordID = manifest.here!.recordID

            self.assureRecordExists(withRecordID: recordID, storageMode: storageMode, recordType: zoneTypeKey) { (iHereRecord: CKRecord?) in
                if iHereRecord == nil || iHereRecord?[zoneNameKey] == nil {
                    self.establishRoot(storageMode, onCompletion)
                } else {
                    manifest.hereZone = self.zoneForRecord(iHereRecord!, in: storageMode)

                    onCompletion?(0)
                }
            }
        }
    }


    func establishRoot(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let recordID = CKRecordID(recordName: rootNameKey)

        self.assureRecordExists(withRecordID: recordID, storageMode: storageMode, recordType: zoneTypeKey) { (iRecord: CKRecord?) in
            let record = iRecord ?? CKRecord(recordType: zoneTypeKey, recordID: recordID)
            let   root = self.zoneForRecord(record, in: storageMode)
            root.level = 0

            gTravelManager.setRoot(root, for: storageMode)
            root.clearAllStates()
            root.needChildren()
            root.needSave()

            if iRecord == nil {
                root.needCreate()
            }

            onCompletion?(0)
        }
    }


    // MARK:- remote persistence
    // MARK:-


    func resetBadgeCounter() {
        container?.accountStatus { (iStatus, iError) in
            if iStatus == .available {
                let badgeResetOperation = CKModifyBadgeOperation(badgeValue: 0)

                badgeResetOperation.modifyBadgeCompletionBlock = { (error) -> Void in
                    if error == nil {
                        zapplication.clearBadge()
                    }
                }

                self.container?.add(badgeResetOperation)
            }
        }
    }


    func unsubscribe(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        if  let db = databaseForMode(storageMode) {
            db.fetchAllSubscriptions { (iSubscriptions: [CKSubscription]?, iError: Error?) in
                if iError != nil {
                    onCompletion?(0)
                    self.reportError(iError)
                } else {
                    var count: Int = iSubscriptions!.count

                    if count == 0 {
                        onCompletion?(0)
                    } else {
                        for subscription: CKSubscription in iSubscriptions! {
                            db.delete(withSubscriptionID: subscription.subscriptionID, completionHandler: { (iSubscription: String?, iUnsubscribeError: Error?) in
                                if iUnsubscribeError != nil {
                                    self.reportError(iUnsubscribeError)
                                }

                                count -= 1

                                if count == 0 {
                                    onCompletion?(0)
                                }
                            })
                        }
                    }
                }
            }
        } else {
            onCompletion?(0)
        }
    }


    func subscribe(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        if  let         db = databaseForMode(storageMode) {
            let classNames = [zoneTypeKey, manifestTypeKey]
            var      count = classNames.count

            for className: String in classNames {
                let    predicate:          NSPredicate = NSPredicate(value: true)
                let subscription:       CKSubscription = CKQuerySubscription(recordType: className, predicate: predicate, options: [.firesOnRecordUpdate])
                let  information:   CKNotificationInfo = CKNotificationInfo()
                information.alertLocalizationKey       = "new Focus data has arrived";
                information.shouldBadge                = true
                information.shouldSendContentAvailable = true
                subscription.notificationInfo          = information

                db.save(subscription, completionHandler: { (iSubscription: CKSubscription?, iSubscribeError: Error?) in
                    if iSubscribeError != nil {
                        self.signalFor(iSubscribeError as NSObject?, regarding: .error)
                        self.reportError(iSubscribeError)
                    }

                    count -= 1
                    
                    if count == 0 {
                        onCompletion?(0)
                    }
                })
            }
        } else {
            onCompletion?(0)
        }
    }


    func setIntoObject(_ object: ZRecord, value: NSObject?, for property: String) {
        if  let     mode = object.storageMode, databaseForMode(mode) != nil, let record = object.record {
            let oldValue = record[property] as? NSObject

            if oldValue         != value {
                record[property] = value as! CKRecordValue?

                object.maybeNeedMerge()
            }
        }
    }


    func getFromObject(_ object: ZRecord, valueForPropertyName: String) {
        if  let mode = object.storageMode, let db = databaseForMode(mode), object.record != nil, gOperationsManager.isReady {
            let      predicate = NSPredicate(value: true)
            let  type: String  = NSStringFromClass(type(of: object)) as String
            let query: CKQuery = CKQuery(recordType: type, predicate: predicate)

            db.perform(query, inZoneWith: nil) { (iResults: [CKRecord]?, performanceError: Error?) in
                if performanceError != nil {
                    self.signalFor(performanceError as NSObject?, regarding: .error)
                } else {
                    let        record: CKRecord = (iResults?[0])!
                    object.record[valueForPropertyName] = (record as! CKRecordValue)

                    self.signalFor(nil, regarding: .redraw)
                }
            }
        }
    }
}

