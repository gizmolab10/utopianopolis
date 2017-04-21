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
        if let database = databaseForMode(mode) {
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

                toConsole("creating \(count)")

                operation.start()

                return
            }
        }

        onCompletion?(0)
    }


    func stringFor(_ records: [CKRecord]?) -> String {
        var string = ""

        if records != nil {
            for record in records! {
                let value = record[zoneNameKey] as? String ?? record.recordID.recordName

                string.append("\n         \(value)")
            }
        }

        return string
    }


    func flush(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        if  let           operation = configure(CKModifyRecordsOperation(), using: storageMode) as? CKModifyRecordsOperation {
            operation.recordsToSave = recordsWithMatchingStates([.needsSave], in: storageMode)

            clearStates([.needsSave], in: storageMode) // clear BEFORE looking at manifest

            if operation.recordsToSave!.count > 0 {

                toConsole("saving \((operation.recordsToSave?.count)!) ==> \(storageMode)\(stringFor(operation.recordsToSave))")

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

                            self.report(description)
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

        self.queryWith(predicate, storageMode: gStorageMode) { (iRecord: CKRecord?) in
            if iRecord != nil {
                self.report("deleting \(String(describing: iRecord![zoneNameKey]))")
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


    func fetchManifest(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        gFavoritesManager.setup()

        let         manifestName = manifestNameForMode(storageMode)
        let recordID: CKRecordID = CKRecordID(recordName: manifestName)

        assureRecordExists(withRecordID: recordID, storageMode: .mine, recordType: manifestTypeKey) { (iManifestRecord: CKRecord?) in
            if iManifestRecord != nil {
                let    manifest = gTravelManager.manifest(for: storageMode)
                manifest.record = iManifestRecord
            }

            onCompletion?(0)
        }
    }


    func fetchScaffold(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        // fetch all zones between here and root
        var    zone:    Zone? = gHere
        var closure: Closure? = nil

        zone?.needParent()

        closure = {
            self.fetchParents(storageMode) { (iResult: Int) in
                let parent = zone?.parentZone

                if  parent == nil {
                    gRoot = zone!

                    gHere.updateProgenyCounts()
                    onCompletion?(0)
                } else {
                    zone = parent

                    zone?.needParent()
                    closure?()
                }
            }
        }

        closure?()
    }


    func establishHere(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let manifest = gTravelManager.manifest(for: storageMode)

        if manifest.here == nil {
            self.establishRoot(storageMode, onCompletion)
        } else {
            let recordID = manifest.here!.recordID

            self.assureRecordExists(withRecordID: recordID, storageMode: storageMode, recordType: zoneTypeKey) { (iHereRecord: CKRecord?) in
                if iHereRecord == nil || iHereRecord?[zoneNameKey] == nil {
                    self.establishRoot(storageMode, onCompletion)
                } else {
                    gHere = self.zoneForRecord(iHereRecord!, in: storageMode)

                    onCompletion?(0)
                }
            }
        }
    }


    func establishRoot(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let recordID = CKRecordID(recordName: rootNameKey)

        self.assureRecordExists(withRecordID: recordID, storageMode: gStorageMode, recordType: zoneTypeKey) { (iRecord: CKRecord?) in
            if iRecord != nil { // NEED TODO storage mode, i.e., the database
                // get from the record id's cloud zone
                gRoot       = self.zoneForRecord(iRecord!, in: storageMode)
                gRoot.level = 0

                gRoot.needChildren()
            }

            onCompletion?(0)
        }
    }
    

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

                            self.invokeWithMode(storageMode) {
                                gfileManager.save()
                            }
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


    func fetchChildren(_ storageMode: ZStorageMode, _ recursiveGoal: Int? = nil, _ onCompletion: IntegerClosure?) {
        let childrenNeeded = referencesWithMatchingStates([.needsChildren], in: storageMode)

        if childrenNeeded.count == 0 {
            onCompletion?(0)
        } else {
            var parentsNeedingResort = [Zone] ()
            let            predicate = NSPredicate(format: "zoneState < %d AND parent IN %@", ZoneState.IsFavorite.rawValue, childrenNeeded)
            let                zones = zoneNamesWithMatchingStates([.needsChildren], in: storageMode)

            onCompletion?(childrenNeeded.count)
            clearState(.needsChildren, in: storageMode)
            toConsole("fetching children of \(zones)")
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
                        if recursiveGoal != nil && recursiveGoal! > child.level {
                            child.maybeNeedChildren()
                        }

                        if let parent  = child.parentZone {
                            if parent != child && !parent.children.contains(child) {
                                parent.addChild(child)

                                if !parentsNeedingResort.contains(parent) {
                                    parentsNeedingResort.append(parent)
                                }
                            }
                        } else {
                            self.report(child.zoneName)
                        }
                    }
                }
            }
        }
    }


    func cloudLogic(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        fetchCloudZones(storageMode) { value in
            onCompletion?(value)
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


    func merge(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let recordIDs = recordIDsWithMatchingStates([.needsMerge], in: storageMode)

        if  recordIDs.count > 0, let operation = configure(CKFetchRecordsOperation(), using: storageMode) as? CKFetchRecordsOperation {
            onCompletion?(recordIDs.count)

            operation.recordIDs                = recordIDs
            operation.completionBlock          = { onCompletion?(0) }
            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                if let error: CKError = iError as? CKError {
                    self.reportError(error)
                } else if let record = self.recordForRecordID(iID, in: storageMode) {
                    record.mergeIntoAndTake(iRecord!)
                }
            }

            operation.start()
        } else {
            onCompletion?(0)
        }
    }


    func fetchParents(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let missingParents = parentIDsWithMatchingStates([.needsParent], in: storageMode)
        let        orphans = recordIDsWithMatchingStates([.needsParent], in: storageMode)

        if  missingParents.count > 0, let operation = configure(CKFetchRecordsOperation(), using: storageMode) as? CKFetchRecordsOperation {
            onCompletion?(missingParents.count)
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

            clearState(.needsParent, in: storageMode)

            toConsole("fetching parents \(missingParents.count)")

            operation.start()

            return
        }
        
        onCompletion?(0)
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


    func fetchFavorites(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let predicate = NSPredicate(format: "zoneState >= %d AND zoneState < %d", ZoneState.IsFavorite.rawValue, ZoneState.IsDeleted.rawValue)

        self.queryWith(predicate, storageMode: gStorageMode) { (iRecord: CKRecord?) in
            if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                gFavoritesManager.update()
                gFavoritesManager.favoritesRootZone.respectOrder()
                onCompletion?(0)
            } else {
                let        bookmark = Zone(record: iRecord, storageMode: storageMode)
                let            root = gFavoritesManager.favoritesRootZone
                bookmark.parentZone = root

                root.addChild(bookmark)
            }
        }
    }


    func fetch(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let needed = referencesWithMatchingStates([.needsFetch], in: storageMode)

        if  needed.count == 0 {
            onCompletion?(0)
        } else {
            let predicate = NSPredicate(format: "zoneState < %d AND recordID IN %@", ZoneState.IsFavorite.rawValue, needed)

            onCompletion?(needed.count)

            self.queryWith(predicate, storageMode: gStorageMode) { (iRecord: CKRecord?) in
                if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                    onCompletion?(0)
                } else {
                    if let record = self.recordForCKRecord(iRecord, in: storageMode) {
                        record.unmarkForStates([.needsFetch])    // deferred to make sure fetch worked before clearing fetch flag

                        record.record = iRecord

                        if let zone = record as? Zone {
                            zone.updateProgenyCounts()
                            zone.updateLevel()
                        }
                    }
                }
            }
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


    func setIntoObject(_ object: ZRecord, value: NSObject?, forPropertyName: String) {
        if  databaseForMode(gStorageMode)  != nil {
            if  let                  record = object.record {
                let                oldValue = record[forPropertyName] as? NSObject

                if oldValue                != value {
                    record[forPropertyName] = value as! CKRecordValue?

                    object.maybeNeedMerge()
                }
            }
        }
    }


    func getFromObject(_ object: ZRecord, valueForPropertyName: String) {
        if  let db = databaseForMode(gStorageMode), object.record != nil, gOperationsManager.isReady {
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

