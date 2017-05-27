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
    var database: CKDatabase? { return gRemoteStoresManager.databaseForMode(storageMode) }

    
    func configure(_ operation: CKDatabaseOperation) -> CKDatabaseOperation? {
        if  database != nil {
            operation.qualityOfService = .background
            operation.container        = gRemoteStoresManager.container
            operation.database         = database

            return operation
        }

        return nil
    }


    // MARK:- push to cloud
    // MARK:-


    func create(_ onCompletion: IntegerClosure?) {
        if  let           operation = configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
            operation.recordsToSave = recordsWithMatchingStates([.needsCreate])

            clearState(.needsCreate)

            if let count = operation.recordsToSave?.count, count > 0 {
                operation.completionBlock = { onCompletion?(0) }
                onCompletion?(count)
                operation.start()

                return
            }
        }

        onCompletion?(0)
    }


    func flush(_ onCompletion: IntegerClosure?) {
        if  let           operation = configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
            operation.recordsToSave = recordsWithMatchingStates([.needsSave])

            clearStates([.needsSave]) // clear BEFORE looking at manifest

            if let count = operation.recordsToSave?.count, count > 0 {
                var prefix = "SAVE \(count)"

                prefix.appendSpacesToLength(14)
                performance("\(prefix)\(stringForRecords(operation.recordsToSave))")

                operation.completionBlock = {
                    // deal with saved records marked as deleted
                    for record: CKRecord in operation.recordsToSave! {
                        if let zone = self.zoneForRecordID(record.recordID), zone.isDeleted {
                            self.unregisterZone(zone)
                        }
                    }

                    onCompletion?(0)
                }

                operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iError: Error?) in
                    // mark failed records as needing merge
                    if  let error:  CKError = iError as? CKError {
                        let info            = error.errorUserInfo
                        var description     = info["CKErrorDescription"] as! String

                        if  description    != "record to insert already exists" {
                            if  let  record = self.recordForCKRecord(iRecord) {
                                record.maybeNeedMerge()
                            }

                            if  let    name = iRecord?[zoneNameKey] as? String {
                                description = "\(description): \(name)"
                            }

                            self.performance("SAVE ==> \(self.storageMode) \(description)")
                        }
                    }
                }

                operation.start()

                return
            }
        }

        onCompletion?(0)
    }


    func emptyTrash(_ onCompletion: IntegerClosure?) {
        let   predicate = NSPredicate(format: "zoneState <= %d", ZoneState.IsDeleted.rawValue)
        var toBeDeleted = [CKRecordID] ()

        self.queryWith(predicate) { (iRecord: CKRecord?) in
            if iRecord != nil {
                self.performance("DELETE \(String(describing: iRecord![zoneNameKey]))")
                toBeDeleted.append((iRecord?.recordID)!)

            } else { // iRecord == nil means: end of response to this particular query

                if (toBeDeleted.count) > 0, let operation = self.configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
                    operation.completionBlock   = { onCompletion?(0) }
                    operation.recordIDsToDelete = toBeDeleted   // delete them

                    operation.start()
                } else {
                    onCompletion?(0)
                }
            }
        }
    }


    func undeleteAll(_ onCompletion: IntegerClosure?) {
        let predicate = NSPredicate(format: "zoneState >= %d", ZoneState.IsDeleted.rawValue) // "parent = nil")

        onCompletion?(-1)

        self.queryWith(predicate) { (iRecord: CKRecord?) in
            if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                onCompletion?(0)
            } else {
                let            root = gRemoteStoresManager.rootZone(for: self.storageMode)
                let         deleted = self.recordForCKRecord(iRecord) as? Zone ?? Zone(record: iRecord, storageMode: self.storageMode)
                deleted  .isDeleted = false

                if  deleted.parent != nil {
                    deleted.needParent()
                } else {
                    deleted.parentZone = root

                    root?.needFetch()
                }

                deleted.maybeNeedMerge()
                deleted.updateCloudProperties()
            }
        }
    }


    // MARK:- request from cloud
    // MARK:-


    func assureRecordExists(withRecordID recordID: CKRecordID, recordType: String, onCompletion: @escaping RecordClosure) {
        let closure: RecordClosure = { (record: CKRecord?) in
            self.dispatchAsyncInForeground {
                onCompletion(record)
            }
        }

        if  database == nil {
            closure(nil)
        } else {
            database?.fetch(withRecordID: recordID) { (fetchedRecord: CKRecord?, fetchError: Error?) in
                if  fetchError == nil && fetchedRecord != nil {
                    closure(fetchedRecord)
                } else {
                    let created: CKRecord = CKRecord(recordType: recordType, recordID: recordID)

                    self.database?.save(created) { (savedRecord: CKRecord?, saveError: Error?) in
                        if (saveError != nil) {
                            closure(nil)
                        } else {
                            closure(savedRecord!)
                            gfileManager.save(to: self.storageMode)
                        }
                    }
                }
            }
        }
    }


    func queryWith(_ predicate: NSPredicate, onCompletion: RecordClosure?) {
        if  let                operation = configure(CKQueryOperation()) as? CKQueryOperation {
            operation             .query = CKQuery(recordType: zoneTypeKey, predicate: predicate)
            operation       .desiredKeys = Zone.cloudProperties()
            operation.recordFetchedBlock = { iRecord in
                onCompletion?(iRecord)
            }

            operation.queryCompletionBlock = { (cursor, error) in
                if error != nil {
                    self.reportError(error, predicate.description)
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


    func searchFor(_ searchFor: String, onCompletion: ObjectClosure?) {
        let predicate = searchPredicateFrom(searchFor)
        var   records = [CKRecord] ()

        queryWith(predicate) { iRecord in
            if iRecord != nil {
                records.append(iRecord!)
            } else {
                onCompletion?(records as NSObject)
            }
        }
    }


    func merge(_ onCompletion: IntegerClosure?) {
        let recordIDs = recordIDsWithMatchingStates([.needsMerge])
        let     count = recordIDs.count

        if  count > 0, let operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            self.performance("MERGE         \(stringForRecordIDs(recordIDs, in: storageMode))")

            operation.recordIDs                = recordIDs
            operation.completionBlock          = { onCompletion?(0) }
            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                if  let record = self.recordForRecordID(iID) {
                    let   name = record.record[zoneNameKey] as? String ?? "---"

                    if let error: CKError = iError as? CKError {
                        self.reportError("MERGE ==> \(self.storageMode) \(error) \(name)")
                    } else {
                        record.mergeIntoAndTake(iRecord!)
                    }
                }

                self.clearStatesForRecordID(iID, forStates:[.needsMerge])
            }

            operation.start()
        } else {
            onCompletion?(0)
        }
    }


    // MARK:- fetch
    // MARK:-


    func fetch(_ onCompletion: IntegerClosure?) {
        let needed = referencesWithMatchingStates([.needsFetch])
        let  count = needed.count

        onCompletion?(count)

        if count > 0 {
            let predicate = NSPredicate(format: "zoneState < %d AND recordID IN %@", ZoneState.IsFavorite.rawValue, needed)

            performance("FETCH         \(stringForReferences(needed, in: storageMode))")

            self.queryWith(predicate) { (iRecord: CKRecord?) in
                if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                    onCompletion?(0)
                } else {
                    if let record = self.recordForCKRecord(iRecord) {
                        record.unmarkForAllOfStates([.needsFetch])    // deferred to make sure fetch worked before clearing fetch flag

                        record.record = iRecord

                        if let zone = record as? Zone {
                            zone.updateLevel()
                        }
                    }
                }
            }
        }
    }


    func fetchFavorites(_ onCompletion: IntegerClosure?) {
        let predicate = NSPredicate(format: "zoneState >= %d AND zoneState < %d", ZoneState.IsFavorite.rawValue, ZoneState.IsDeleted.rawValue)

        onCompletion?(-1)

        self.queryWith(predicate) { (iRecord: CKRecord?) in
            let root = gFavoritesManager.rootZone

            if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                gFavoritesManager.update()
                root?.respectOrder()
                onCompletion?(0)
            } else {
                let        favorite = Zone(record: iRecord, storageMode: self.storageMode)
                favorite.parentZone = root
                var    isDuplicated = false

                // avoid adding a duplicate (which was created by a bug)

                if  let                 name  = favorite.zoneName, root != nil {
                    for zone: Zone in root!.children {
                        if  let         link  = favorite.zoneLink {
                            if          link == zone.zoneLink {
                                isDuplicated  = true

                                break
                            }
                        }

                        if name == zone.zoneName {
                            isDuplicated   = true

                            break
                        }
                    }
                }

                if !isDuplicated {
                    root?.addChild(favorite)
                } else {
                    favorite.isDeleted = true
                    
                    favorite.needSave()
                }
            }
        }
    }


    func fetchManifest(_ onCompletion: IntegerClosure?) {
        onCompletion?(-1)

        let     mine = gRemoteStoresManager.cloudManagerFor(.mine)
        let manifest = gRemoteStoresManager.manifest(for: storageMode)
        let recordID = manifest.record.recordID

        mine.assureRecordExists(withRecordID: recordID, recordType: manifestTypeKey) { (iManifestRecord: CKRecord?) in
            if iManifestRecord != nil {
                manifest.record = iManifestRecord
            }

            onCompletion?(0)
        }
    }


    func fetchToRoot(_ onCompletion: IntegerClosure?) {
        let                  manifest = gRemoteStoresManager.manifest(for: self.storageMode)
        var           visited: [Zone] = []
        var getParentOf: ZoneClosure? = nil

        getParentOf = { iZone in
            if visited.contains(iZone) || iZone.isRoot || iZone.isRootOfFavorites {
                onCompletion?(0)
            } else {
                iZone.needParent()

                self.fetchParents() { iResult in
                    if iResult == 0 {
                        if  let parent = iZone.parentZone {
                            visited    = visited + [iZone]

                            getParentOf?(parent)    // continue
                        } else {
                            self.rootZone = iZone   // got root

                            onCompletion?(0)
                        }
                    }
                }
            }
        }
        
        onCompletion?(-1)
        getParentOf?(manifest.hereZone)
    }


    func fetchParents(_ onCompletion: IntegerClosure?) {
        let missingParents = parentIDsWithMatchingStates([.needsParent])
        let        orphans = recordIDsWithMatchingStates([.needsParent])

        if  missingParents.count > 0, let operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            operation.recordIDs       = missingParents
            operation.completionBlock = { onCompletion?(0) }
            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                var parent = self.zoneForRecordID(iID)

                if parent != nil && iRecord != nil {
                    parent?.mergeIntoAndTake(iRecord!) // BROKEN: likely this does not do what's needed here
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

                if parent != nil {
                    parent?.updateLevel()
                }
            }

            performance("PARENTS of    \(stringForRecordIDs(orphans, in: storageMode))")
            clearState(.needsParent)
            operation.start()
        } else {
            onCompletion?(0)
        }
    }


    func fetchChildren(_ iLogic: ZRecursionLogic? = ZRecursionLogic(.restore), _ onCompletion: IntegerClosure?) {
        let  progenyNeeded = referencesWithMatchingStates([.needsProgeny])
        let childrenNeeded = referencesWithMatchingStates([.needsChildren]) + progenyNeeded
        let          logic = iLogic ?? ZRecursionLogic(.restore)
        let          count = childrenNeeded.count

        onCompletion?(count)

        if count > 0 {
            var parentsNeedingResort = [Zone] ()
            let            predicate = NSPredicate(format: "zoneState < %d AND parent IN %@", ZoneState.IsFavorite.rawValue, childrenNeeded)

            clearStates([.needsChildren, .needsProgeny])
            performance("CHILDREN of   \(stringForReferences(childrenNeeded, in: storageMode))")
            queryWith(predicate) { (iRecord: CKRecord?) in
                if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                    for parent in parentsNeedingResort {
                        parent.respectOrder()
                    }

                    self.fetchChildren(logic, onCompletion) // recurse to grab children of received children
                } else {
                    let child = self.zoneForRecord(iRecord!)

                    if !child.isDeleted {
                        logic.applyChildLogic(to: child, progenyNeeded)

                        if let parent = child.parentZone {
                            if parent != child && !parent.children.contains(child) {
                                parent.addChild(child)

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


    func fetchCloudZones(_ onCompletion: IntegerClosure?) {
        onCompletion?(-1)

        if let                              operation = configure(CKFetchRecordZonesOperation()) as? CKFetchRecordZonesOperation {
            operation.fetchRecordZonesCompletionBlock = { (recordZonesByZoneID, operationError) in
                self.cloudZonesByID                   = recordZonesByZoneID!

                gRemoteStoresManager.resetBadgeCounter()

                onCompletion?(0)
            }

            operation.start()
        } else {
            onCompletion?(0)
        }
    }


    func establishHere(_ onCompletion: IntegerClosure?) {
        let manifest = gRemoteStoresManager.manifest(for: storageMode)

        let rootCompletion: IntegerClosure = { iValue in
            if iValue == 0 {
                self.rootZone?.needProgeny()
            }

            onCompletion?(iValue)
        }

        if manifest.here == nil {
            self.establishRoot(rootCompletion)
        } else {
            let recordID = manifest.here!.recordID

            self.assureRecordExists(withRecordID: recordID, recordType: zoneTypeKey) { (iHereRecord: CKRecord?) in
                if iHereRecord == nil || iHereRecord?[zoneNameKey] == nil {
                    self.establishRoot(rootCompletion)
                } else {
                    let          here = self.zoneForRecord(iHereRecord!)
                    here      .record = iHereRecord
                    manifest.hereZone = here

                    here.needProgeny()
                    onCompletion?(0)
                }
            }
        }
    }


    func establishRoot(_ onCompletion: IntegerClosure?) {
        let recordID = CKRecordID(recordName: rootNameKey)

        onCompletion?(-1)

        assureRecordExists(withRecordID: recordID, recordType: zoneTypeKey) { (iRecord: CKRecord?) in
            if iRecord != nil {
                let      root = self.zoneForRecord(iRecord!)    // got root
                root  .record = iRecord!
                self.rootZone = root
                root   .level = 0

                root.needChildren()
            }

            onCompletion?(0)
        }
    }


    // MARK:- remote persistence
    // MARK:-


    func unsubscribe(_ onCompletion: IntegerClosure?) {
        if  database == nil {
            onCompletion?(0)
        } else {
            onCompletion?(-1)
            database!.fetchAllSubscriptions { (iSubscriptions: [CKSubscription]?, iError: Error?) in
                if iError != nil {
                    onCompletion?(0)
                    self.reportError(iError)
                } else {
                    var count: Int = iSubscriptions!.count

                    if count == 0 {
                        onCompletion?(0)
                    } else {
                        for subscription: CKSubscription in iSubscriptions! {
                            self.database!.delete(withSubscriptionID: subscription.subscriptionID, completionHandler: { (iSubscription: String?, iUnsubscribeError: Error?) in
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
        }
    }


    func subscribe(_ onCompletion: IntegerClosure?) {
        if  database == nil {
            onCompletion?(0)
        } else {
            let classNames = [zoneTypeKey, manifestTypeKey]
            var      count = classNames.count

            onCompletion?(-1)
            for className: String in classNames {
                let    predicate:          NSPredicate = NSPredicate(value: true)
                let subscription:       CKSubscription = CKQuerySubscription(recordType: className, predicate: predicate, options: [.firesOnRecordUpdate])
                let  information:   CKNotificationInfo = CKNotificationInfo()
                information.alertLocalizationKey       = "new Focus data has arrived";
                information.shouldBadge                = true
                information.shouldSendContentAvailable = true
                subscription.notificationInfo          = information

                database!.save(subscription, completionHandler: { (iSubscription: CKSubscription?, iSubscribeError: Error?) in
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
        }
    }


    func setIntoObject(_ object: ZRecord, value: NSObject?, for property: String) {
        if  let   record = object.record, database != nil {
            let oldValue = record[property] as? NSObject

            if oldValue         != value {
                record[property] = value as! CKRecordValue?

                object.maybeNeedMerge()
            }
        }
    }


    func getFromObject(_ object: ZRecord, valueForPropertyName: String) {
        if  database != nil &&
            object.record != nil &&
            gOperationsManager.isReady {
            let      predicate = NSPredicate(value: true)
            let  type: String  = NSStringFromClass(type(of: object)) as String
            let query: CKQuery = CKQuery(recordType: type, predicate: predicate)

            database?.perform(query, inZoneWith: nil) { (iResults: [CKRecord]?, performanceError: Error?) in
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

