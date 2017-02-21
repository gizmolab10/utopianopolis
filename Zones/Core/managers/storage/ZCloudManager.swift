//
//  ZCloudManager.swift
//  Zones
//
//  Created by Jonathan Sand on 9/18/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


enum ZStorageMode: String {     ///// move this to cloud manager  //////////
    case favorites = "favorites"
    case everyone  = "everyone"
    case shared    = "group"
    case mine      = "mine"
}


class ZCloudManager: ZRecordsManager {
    var cloudZonesByID = [CKRecordZoneID : CKRecordZone] ()
    var        container: CKContainer!
    var        currentDB: CKDatabase? { get { return databaseForMode(gStorageMode) } }


    func databaseForMode(_ mode: ZStorageMode) -> CKDatabase? {
        switch mode {
        case .everyone: return container.publicCloudDatabase
        case .shared:   return container.sharedCloudDatabase
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
        return configure(operation, using: gStorageMode)
    }


    // MARK:- receive from cloud
    // MARK:-


    func receivedUpdateFor(_ recordID: CKRecordID) {
        resetBadgeCounter()
        assureRecordExists(withRecordID: recordID, storageMode: gStorageMode, recordType: zoneTypeKey) { iRecord in
            let   zone = self.zoneForRecord(iRecord!)
            let parent = zone.parentZone

            if  zone.showChildren {
                self.dispatchAsyncInForeground {
                    self.signalFor(parent, regarding: .redraw)

                    gOperationsManager.children(recursively: false) {
                        self.signalFor(parent, regarding: .redraw)
                    }
                }
            }
        }
    }


    // MARK:- push to cloud
    // MARK:-


    func royalFlush(_ onCompletion: @escaping Closure) {
        for zone in zones.values {
            if !zone.isMarkedForStates([.needsFetch, .needsSave, .needsCreate]) {
                zone.normalizeOrdering()
                zone.updateCloudProperties()
            }
        }

        gOperationsManager.sync(onCompletion)
    }


    func create(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        if  let           operation = configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
            operation.recordsToSave = recordsWithMatchingStates([.needsCreate])

            clearState(.needsCreate)

            if (operation.recordsToSave?.count)! > 0 {
                operation.completionBlock = { onCompletion?(0) }

                toConsole("creating \((operation.recordsToSave?.count)!)")

                operation.start()

                return
            }
        }

        onCompletion?(0)
    }


    func flush(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        if  let           operation = configure(CKModifyRecordsOperation(), using: storageMode) as? CKModifyRecordsOperation {
            operation.recordsToSave = recordsWithMatchingStates([.needsSave])

            clearStates([.needsSave]) // clear BEFORE looking at manifest

            if (operation.recordsToSave?.count)! > 0 {

                toConsole("saving \((operation.recordsToSave?.count)!)")

                operation.completionBlock          = {
                    self.invokeWithMode(storageMode) {

                        // deal with saved records marked as deleted
                        for record: CKRecord in operation.recordsToSave! {
                            if let zone = self.zoneForRecordID(record.recordID), zone.isDeleted {
                                self.unregisterZone(zone)
                            }
                        }
                    }

                    onCompletion?(0)
                }

                operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iError: Error?) in

                    // mark failed records as needing fetch
                    if  let error:         CKError = iError as? CKError {
                        let info                   = error.errorUserInfo
                        var description:    String = info["ServerErrorDescription"] as! String

                        if  description           != "record to insert already exists" {
                            self.invokeWithMode(storageMode) {
                                if let record      = self.recordForRecordID((iRecord?.recordID)!) {
                                    record.needFetch()
                                }

                                if let name        = iRecord?["zoneName"] as! String? {
                                    description    = "\(description): \(name)"
                                }

                                self.reportError(description)
                            }
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

        self.cloudQueryUsingPredicate(predicate) { (iRecord: CKRecord?) in
            if iRecord != nil {
                self.report("deleting \(iRecord![zoneNameKey])")
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
                let    manifest = gTravelManager.manifest
                manifest.record = iManifestRecord
            }

            onCompletion?(0)
        }
    }


    func establishHere(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        if gTravelManager.manifest.here != nil {
            let recordID = (gTravelManager.manifest.here?.recordID)!

            self.assureRecordExists(withRecordID: recordID, storageMode: storageMode, recordType: zoneTypeKey) { (iHereRecord: CKRecord?) in
                if iHereRecord == nil || iHereRecord?[zoneNameKey] == nil {
                    self.establishRootAsHere(storageMode, onCompletion)
                } else {
                    gHere = self.zoneForRecord(iHereRecord!)

                    gTravelManager.manifest.needUpdateSave()

                    onCompletion?(0)
                }
            }
        } else {
            self.establishRootAsHere(storageMode, onCompletion)
        }
    }


    func establishRootAsHere(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let recordID = CKRecordID(recordName: rootNameKey)

        self.assureRecordExists(withRecordID: recordID, storageMode: gStorageMode, recordType: zoneTypeKey) { (iRecord: CKRecord?) in
            if iRecord != nil {
                let               root = self.zoneForRecord(iRecord!)
                gTravelManager.rootZone = root
                root.level             = 0

                gTravelManager.manifest.needUpdateSave()
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
                            gfileManager.save()
                        }
                    })
                }
            }
        }
    }


    func cloudQueryUsingPredicate(_ predicate: NSPredicate, onCompletion: RecordClosure?) {
        if  let                operation = configure(CKQueryOperation()) as? CKQueryOperation {
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


    func searchFor(_ searchFor: String, onCompletion: ObjectClosure?) {
        let predicate = searchPredicateFrom(searchFor)
        var   records = [CKRecord] ()

        cloudQueryUsingPredicate(predicate) { iRecord in
            if iRecord != nil {
                records.append(iRecord!)
            } else {
                onCompletion?(records as NSObject)
            }
        }
    }


    @discardableResult func fetchChildren(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) -> Bool {
        let childrenNeeded = referencesWithMatchingStates([.needsChildren])
        let noMoreChildren = childrenNeeded.count == 0

        if noMoreChildren {
            onCompletion?(0)
        } else {
            var parentsNeedingResort = [Zone] ()
            let            predicate = NSPredicate(format: "zoneState < %d AND parent IN %@", ZoneState.IsFavorite.rawValue, childrenNeeded)
            let                zones = zoneNamesWithMatchingStates([.needsChildren])

            onCompletion?(childrenNeeded.count)
            clearState(.needsChildren)
            toConsole("fetching children of \(zones)")
            cloudQueryUsingPredicate(predicate) { (iRecord: CKRecord?) in
                if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                    for parent in parentsNeedingResort {
                        parent.respectOrder()
                    }

                    // self.signalFor(nil, regarding: .redraw)

                    self.fetchChildren(storageMode, onCompletion) // recurse: try another fetch
                } else {
                    self.invokeWithMode(storageMode) {
                        let child = self.zoneForRecord(iRecord!)

                        if !child.isDeleted {
                            if gRecursivelyFetch {
                                child.needChildren()
                            }

                            if let parent  = child.parentZone {
                                if parent != child && !parent.children.contains(child) {
                                    parent.addChild(child)

                                    if !parentsNeedingResort.contains(parent) {
                                        parentsNeedingResort.append(parent)
                                    }
                                }

                                return
                            }
                            
                            self.reportError(child.zoneName)
                        }
                    }
                }
            }
        }
        
        return noMoreChildren
    }


    func cloudLogic(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        fetchCloudZones(storageMode) { value in
            onCompletion?(value)
        }
    }


    func fetchCloudZones(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        container = CKContainer(identifier: cloudID)

        if let                              operation = configure(CKFetchRecordZonesOperation()) as? CKFetchRecordZonesOperation {
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
        let recordIDs = recordIDsWithMatchingStates([.needsMerge])

        if  recordIDs.count > 0, let operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            onCompletion?(recordIDs.count)

            operation.recordIDs                = recordIDs
            operation.completionBlock          = { onCompletion?(0) }
            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                self.invokeWithMode(storageMode) {
                    if let error: CKError = iError as? CKError {
                        self.reportError(error)
                    } else if let record = self.recordForRecordID(iID) {
                        record.mergeIntoAndTake(iRecord!)
                    }
                }
            }

            operation.start()
        } else {
            onCompletion?(0)
        }
    }


    func fetchParents(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let missingParents = parentIDsWithMatchingStates([.needsParent])
        let orphans        = recordIDsWithMatchingStates([.needsParent])

        if missingParents.count > 0 {
            if let operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
                onCompletion?(missingParents.count)
                operation.recordIDs       = missingParents
                operation.completionBlock = { onCompletion?(0) }
                operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                    self.invokeWithMode(storageMode) {
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
                    }
                }

                clearState(.needsParent)

                toConsole("fetching parents \(missingParents.count)")

                operation.start()

                return
            }
        }
        
        onCompletion?(0)
    }


    func undelete(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let predicate = NSPredicate(format: "zoneState >= %d", ZoneState.IsDeleted.rawValue) // "parent = nil")

        self.cloudQueryUsingPredicate(predicate) { (iRecord: CKRecord?) in
            if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                onCompletion?(0)
            } else {
                let           root = gTravelManager.rootZone
                let        deleted = self.recordForRecordID(iRecord?.recordID) as? Zone ?? Zone(record: iRecord, storageMode: storageMode)
                deleted .isDeleted = false

                if deleted.parent == nil {
                    deleted.parentZone = root

                    root?.needFetch()
                } else {
                    deleted.needParent()
                }

                deleted.needUpdateSave()
            }
        }
    }


    func fetchFavorites(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let predicate = NSPredicate(format: "zoneState >= %d AND zoneState < %d", ZoneState.IsFavorite.rawValue, ZoneState.IsDeleted.rawValue)

        self.cloudQueryUsingPredicate(predicate) { (iRecord: CKRecord?) in
            if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                gFavoritesManager.update()
                gFavoritesManager.favoritesRootZone.respectOrder()
                onCompletion?(0)
            } else {
                let        bookmark = Zone(record: iRecord, storageMode: storageMode)
                let            root = gFavoritesManager.favoritesRootZone
                bookmark.parentZone = root

                // self.report("fetching \(bookmark.zoneName!) order \(bookmark.order)")
                root.addChild(bookmark)
            }
        }
    }


    func fetch(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let needed = referencesWithMatchingStates([.needsFetch])

        if  needed.count == 0 {
            onCompletion?(0)
        } else {
            let predicate = NSPredicate(format: "zoneState < %d AND recordID IN %@", ZoneState.IsFavorite.rawValue, needed)

            onCompletion?(needed.count)

            self.cloudQueryUsingPredicate(predicate) { (iRecord: CKRecord?) in
                if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                    onCompletion?(0)
                } else {
                    self.invokeWithMode(storageMode) {
                        if let record = self.recordForRecordID(iRecord?.recordID) {
                            record.unmarkForStates([.needsFetch])    // deferred to make sure fetch worked before clearing fetch flag

                            record.record = iRecord
                        }
                    }
                }
            }
        }
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


    func unsubscribe(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        if currentDB == nil {
            onCompletion?(0)
        } else {
            currentDB?.fetchAllSubscriptions { (iSubscriptions: [CKSubscription]?, iError: Error?) in
                if iError != nil {
                    onCompletion?(0)
                    self.reportError(iError)
                } else {
                    var count: Int = iSubscriptions!.count

                    if count == 0 {
                        onCompletion?(0)
                    } else {
                        self.invokeWithMode(storageMode) {
                            for subscription: CKSubscription in iSubscriptions! {
                                self.currentDB?.delete(withSubscriptionID: subscription.subscriptionID, completionHandler: { (iSubscription: String?, iDeleteError: Error?) in
                                    if iDeleteError != nil {
                                        self.reportError(iDeleteError)
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
    }


    func subscribe(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        if currentDB == nil {
            onCompletion?(0)
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
                        onCompletion?(0)
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

                    object.needJustSave()
                }
            }
        }
    }


    func getFromObject(_ object: ZRecord, valueForPropertyName: String) {
        if currentDB != nil && object.record != nil && gOperationsManager.isReady {
            let      predicate = NSPredicate(value: true)
            let  type: String  = NSStringFromClass(type(of: object)) as String
            let query: CKQuery = CKQuery(recordType: type, predicate: predicate)

            currentDB?.perform(query, inZoneWith: nil) { (iResults: [CKRecord]?, performanceError: Error?) in
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

