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


    func start(_ operation: CKOperation) {
        BACKGROUND {     // not stall foreground processor
            operation.start()
        }
    }


    // MARK:- push to cloud
    // MARK:-


    func create(_ onCompletion: IntegerClosure?) {
        let needCreating = pullRecordsWithMatchingStates([.needsCreate])
        let        count = needCreating.count

        onCompletion?(count)

        if  count > 0, let  operation = configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
            operation  .recordsToSave = needCreating
            operation.completionBlock = {
                self.create(onCompletion) // process remaining
            }

            columnarReport("CREATE \(count)", stringForRecords(operation.recordsToSave))
            start(operation)
        }
    }


    func save(_ onCompletion: IntegerClosure?) {
        let deletes = recordIDsWithMatchingStates([.needsDestroy], pull: true)
        let   saves = pullRecordsWithMatchingStates([.needsSave])  // clears state BEFORE looking at manifest
        let   count = saves.count + deletes.count

        onCompletion?(count)

        if  count > 0, let           operation = configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
            operation       .recordIDsToDelete = deletes
            operation           .recordsToSave = saves
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

                        self.columnarReport("SAVE ERROR", "\(self.storageMode) \(description)")
                    }
                }
            }

            operation.completionBlock   = {
                // deal with saved records marked as deleted

                self.FOREGROUND {
                    for recordID: CKRecordID in deletes {
                        if  let zone = self.zoneForRecordID(recordID) {
                            self.unregisterZone(zone)
                        }
                    }

                    for record: CKRecord in saves {
                        if  let zone = self.zoneForRecordID(record.recordID), zone.isDeleted { // only unregister deleted zones
                            self.unregisterZone(zone)
                        }
                    }

                    self.save(onCompletion)         // process remaining
                }
            }

            if   saves.count > 0 { columnarReport("SAVE \(     saves.count)", stringForRecords(saves)) }
            if deletes.count > 0 { columnarReport("DESTROY \(deletes.count)", stringForRecordIDs(deletes, in: storageMode)) }
            start(operation)
        }
    }


    func emptyTrash(_ onCompletion: IntegerClosure?) {
        let   predicate = NSPredicate(format: "zoneIsDeleted = 1")
        var toBeDeleted = [CKRecordID] ()

        self.queryWith(predicate) { (iRecord: CKRecord?) in
            // iRecord == nil means: end of response to this particular query

            if iRecord != nil {
                self.columnarReport("DELETE", String(describing: iRecord![zoneNameKey]))
                toBeDeleted.append((iRecord?.recordID)!)

            } else if (toBeDeleted.count) > 0, let operation = self.configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
                operation.recordIDsToDelete = toBeDeleted   // delete them
                operation.completionBlock   = {
                    onCompletion?(0)
                }

                self.start(operation)
            } else {
                onCompletion?(0)
            }
        }
    }


    func undeleteAll(_ onCompletion: IntegerClosure?) {
        let predicate = NSPredicate(format: "zoneIsDeleted = 1")

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
        let done: RecordClosure = { (record: CKRecord?) in
            self.FOREGROUND {
                onCompletion(record)
            }
        }

        if  database == nil {
            done(nil)
        } else {
            BACKGROUND {     // not stall foreground processor
                self.database?.fetch(withRecordID: recordID) { (fetchedRecord: CKRecord?, fetchError: Error?) in
                    if  fetchError == nil && fetchedRecord != nil {
                        done(fetchedRecord)
                    } else {
                        let brandNew: CKRecord = CKRecord(recordType: recordType, recordID: recordID)

                        self.database?.save(brandNew) { (savedRecord: CKRecord?, saveError: Error?) in
                            if (saveError != nil) {
                                done(nil)
                            } else {
                                done(savedRecord!)
                                gFileManager.save(to: self.storageMode)
                            }
                        }
                    }
                }
            }
        }
    }


    func queryWith(_ predicate: NSPredicate, onCompletion: RecordClosure?) {
        let nilCompletion = {
            onCompletion?(nil)
        }

        if  let                operation = configure(CKQueryOperation()) as? CKQueryOperation {
            operation             .query = CKQuery(recordType: zoneTypeKey, predicate: predicate)
            operation       .desiredKeys = Zone.cloudProperties()
            operation      .resultsLimit = 1000
            operation.recordFetchedBlock = { iRecord in
                onCompletion?(iRecord)
            }

            operation.queryCompletionBlock = { (cursor, error) in
                if error != nil {
                    self.reportError(error, predicate.description)
                }

                nilCompletion()
            }

            start(operation)
        } else {
            nilCompletion()
        }
    }


    func searchPredicateFrom(_ searchString: String) -> NSPredicate {
        let    tokens = searchString.components(separatedBy: " ")
        var separator = ""
        var    suffix = ""

        for token in tokens {
            if  token    != "" {
                suffix    = "\(suffix)\(separator)SELF CONTAINS \"\(token)\""
                separator = " AND "
            }
        }

        return NSPredicate(format: suffix)
    }


    func bookmarkPredicate(from iRecordIDs: [CKRecordID]) -> NSPredicate {
        let separator = " AND "
        var    suffix = ""

        for identifier in iRecordIDs {
            suffix = String(format: "%@%@SELF CONTAINS \"%@\"", suffix, separator, identifier.recordName)
        }

        return NSPredicate(format: "zoneIsFavorite = 0 and zoneIsDeleted = 0\(suffix)")
    }


    func search(for searchString: String, onCompletion: ObjectClosure?) {
        let predicate = searchPredicateFrom(searchString)
        var retrieved = [CKRecord] ()

        queryWith(predicate) { iRecord in
            if let ckRecord = iRecord {
                if !retrieved.contains(ckRecord) {
                    retrieved.append(ckRecord)
                }
            } else {
                onCompletion?(retrieved as NSObject)
            }
        }
    }


    func bookmarks(_ onCompletion: IntegerClosure?) {
        let recordIDs = recordIDsWithMatchingStates([.needsBookmarks], pull: true)
        let     count = recordIDs.count

        onCompletion?(count)

        if  count > 0 {
            let predicate = bookmarkPredicate(from: recordIDs)
            var retrieved = [CKRecord] ()

            queryWith(predicate) { iRecord in
                if let ckRecord = iRecord {
                    if !retrieved.contains(ckRecord) {
                        retrieved.append(ckRecord)
                    }
                } else {
                    for record in retrieved {
                        if self.recordForCKRecord(record) == nil {
                            let _ = Zone(record: iRecord, storageMode: self.storageMode) // register
                        }
                    }

                    self.bookmarks(onCompletion)    // process remaining
                }
            }
        }
    }


    func merge(_ onCompletion: IntegerClosure?) {
        let recordIDs = recordIDsWithMatchingStates([.needsMerge])
        let     count = recordIDs.count

        if  count > 0, let           operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            var                    recordsByID = [CKRecord : CKRecordID?] ()
            operation               .recordIDs = recordIDs
            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                if let record = iRecord {
                    recordsByID[record] = iID
                } else if let error: CKError = iError as? CKError {
                    self.reportError("MERGE ==> \(self.storageMode) \(error)")
                }

                self.clearStatesForRecordID(iID, forStates:[.needsMerge])
            }

            operation.completionBlock = {
                self.FOREGROUND {
                    for (iRecord, iID) in recordsByID {
                        if  let record = self.recordForRecordID(iID) {
                            record.mergeIntoAndTake(iRecord)
                        }
                    }

                    self.merge(onCompletion)        // process remaining
                }
            }
            
            self.columnarReport("MERGE", stringForRecordIDs(recordIDs, in: storageMode))
            start(operation)
        } else {
            onCompletion?(0)
        }
    }


    // MARK:- fetch
    // MARK:-


    func fetchTrash(_ onCompletion: IntegerClosure?) {
        if  let       trash = trashZone {
            let   predicate = NSPredicate(format: "zoneIsDeleted = 1")
            var   retrieved = [CKRecord] ()

            self.queryWith(predicate) { (iRecord: CKRecord?) in
                if let ckRecord = iRecord {
                    if !retrieved.contains(ckRecord) {
                        retrieved.append(ckRecord)
                    }
                } else { // nil means: we already received full response from cloud for this particular fetch
                    self.FOREGROUND {
                        var needMore = false

                        for ckRecord in retrieved {
                            if !ckRecord.allKeys().contains("parent") && trash.addCKRecord(ckRecord) {
                                needMore = true
                            }
                        }

                        self.trashZone?.needFlush()

                        if needMore {
                            self.fetchTrash(onCompletion)
                        } else {
                            onCompletion?(0)
                        }
                    }
                }
            }
        } else {
            onCompletion?(0)
        }
    }
    

    func fetchAll(_ onCompletion: IntegerClosure?) {
        let   predicate = NSPredicate(format: "zoneName != \"\"")
        let   falseBool = NSNumber(value: false)
        let    trueBool = NSNumber(value: true)
        let   revealKey = "zoneShowChildren"
        let favoriteKey = "zoneIsFavorite"
        let   deleteKey = "zoneIsDeleted"
        var   retrieved = [CKRecord] ()

        self.queryWith(predicate) { (iRecord: CKRecord?) in
            if let ckRecord = iRecord {
                if !retrieved.contains(ckRecord) {
                    retrieved.append(ckRecord)
                }
            } else { // nil means: we already received full response from cloud for this particular fetch
                self.FOREGROUND {
                    for ckRecord in retrieved {
                        if let isDeleted = ckRecord[deleteKey] as? Bool {
                            if isDeleted {
                                ckRecord[favoriteKey] = falseBool
                                ckRecord[  revealKey] = falseBool
                            }
                        } else {
                            ckRecord[deleteKey] = trueBool
                        }

                        self.addCKRecord(ckRecord, for: [.needsSave])
                    }

                    onCompletion?(0)
                }
            }
        }
    }


    func fetch(_ onCompletion: IntegerClosure?) {
        let states = [ZRecordState.needsFetch]
        let needed = referencesWithMatchingStates(states)
        let  count = needed.count

        onCompletion?(count)

        if count > 0 {
            let predicate = NSPredicate(format: "recordID IN %@", needed)
            var retrieved = [CKRecord] ()

            columnarReport("FETCH", stringForReferences(needed, in: storageMode))

            self.queryWith(predicate) { (iRecord: CKRecord?) in
                if let ckRecord = iRecord {
                    if !retrieved.contains(ckRecord) {
                        retrieved.append(ckRecord)
                    }
                } else { // nil means: we already received full response from cloud for this particular fetch
                    self.FOREGROUND {
                        for ckRecord in retrieved {
                            if  let record = self.recordForCKRecord(ckRecord) {
                                record.unmarkForAllOfStates(states)     // deferred to make sure fetch worked before clearing fetch flag

                                record.record = ckRecord
                            }
                        }

                        self.fetch(onCompletion)        // process remaining
                    }
                }
            }
        }
    }


    func fetchFavorites(_ onCompletion: IntegerClosure?) {
        let predicate = NSPredicate(format: "zoneIsFavorite = 1 and zoneIsDeleted = 0")
        var retrieved = [CKRecord] ()

        onCompletion?(-1)
        gFavoritesManager.setup()

        self.queryWith(predicate) { (iRecord: CKRecord?) in
            if let ckRecord = iRecord {
                if !retrieved.contains(ckRecord) {
                    retrieved.append(ckRecord)
                }
            } else {
                // nil means: we already received full response from cloud for this particular fetch
                self.FOREGROUND {
                    if let root = gFavoritesManager.rootZone {
                        for record in retrieved {
                            let        favorite = Zone(record: record, storageMode: self.storageMode)
                            favorite.parentZone = root
                            var    isDuplicated = false

                            // avoid adding a duplicate (which was created by a bug)

                            if  let            name  = favorite.zoneName {
                                for zone: Zone in root.children {
                                    if  let    link  = favorite.zoneLink, link == zone.zoneLink {
                                        isDuplicated = true

                                        break
                                    } else if name == zone.zoneName {
                                        isDuplicated = true

                                        break
                                    }
                                }
                            }

                            if isDuplicated {
                                favorite.isDeleted = true

                                favorite.needFlush()
                            } else if let targetID = favorite.crossLink?.record.recordID, self.zoneForRecordID(targetID) == nil {
                                self.assureRecordExists(withRecordID: targetID, recordType: zoneTypeKey) { iAssuredRecord in
                                    let target = Zone(record: iAssuredRecord, storageMode: self.storageMode)

                                    if  target  .isDeleted {
                                        favorite.isDeleted = true

                                        favorite.needFlush()
                                    } else {
                                        target.maybeNeedRoot()
                                        root.add(favorite)
                                        self.columnarReport(" FAVORITE", target.decoratedName)
                                    }
                                }
                            }
                        }

                        root.traverseAllProgeny() { iZone in
                            iZone.convertToBooleans()
                        }

                        root.respectOrder()
                        onCompletion?(0)
                    }
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


    func fetchParents(_ goal: ZRecursionType, _ onCompletion: IntegerClosure?) {
        let state: ZRecordState = (goal == .all) ? .needsRoot : .needsParent
        let      missingParents = parentIDsWithMatchingStates([state])
        let             orphans = recordIDsWithMatchingStates([state])

        if  missingParents.count > 0, let operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            var     recordsByID = [CKRecord : CKRecordID?] ()
            operation.recordIDs = missingParents

            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                if iRecord != nil {
                    recordsByID[iRecord!] = iID
                } else if let error: CKError = iError as? CKError {
                    self.reportError(error)
                }
            }

            operation.completionBlock = {
                self.FOREGROUND {
                    for (iRecord, iID) in recordsByID {
                        var fetchedParent  = self.zoneForRecordID(iID)

                        if  fetchedParent != nil {
                            fetchedParent?.mergeIntoAndTake(iRecord) // BROKEN: likely this does not do what's needed here .... yikes! HUH?
                        } else {
                            fetchedParent  = self.zoneForRecord(iRecord)

                            for orphan in orphans {
                                if let child = self.zoneForRecordID(orphan), let parentID = child.parentZone?.record.recordID, parentID == fetchedParent?.record.recordID {
                                    fetchedParent?.children.append(child)
                                }
                            }
                        }

                        if  goal == .all, let p = fetchedParent {
                            p.maybeNeedRoot()

                            if  p.hasMissingChildren {
                                p.needChildren()
                            }
                        }
                        
                    }
                    
                    self.clearRecordIDs(orphans, for: [state])
                    self.fetchParents(goal, onCompletion)   // process remaining
                }
            }

            columnarReport("PARENTS of", stringForRecordIDs(orphans, in: storageMode))
            clearState(.needsParent)
            start(operation)
        } else {
            onCompletion?(0)
        }
    }


    func fetchChildren(_ iLogic: ZRecursionLogic? = ZRecursionLogic(.restore), _ onCompletion: IntegerClosure?) {
        let          logic = iLogic              ?? ZRecursionLogic(.restore)
        let  progenyNeeded = pullReferencesWithMatchingStates([.needsProgeny])
        let childrenNeeded = pullReferencesWithMatchingStates([.needsChildren]) + progenyNeeded
        let   destroyedIDs = recordIDsWithMatchingStates([.needsDestroy])
        let          count = childrenNeeded.count

        onCompletion?(count)

        if count > 0 {
            var  retrieved = [CKRecord] ()
            let predicate  = NSPredicate(format: "zoneIsFavorite = 0 AND zoneIsDeleted = 0 AND parent IN %@", childrenNeeded)

            columnarReport("CHILDREN of", stringForReferences(childrenNeeded, in: storageMode))
            queryWith(predicate) { (iRecord: CKRecord?) in
                if  let ckRecord = iRecord {
                    if !retrieved.contains(ckRecord) {
                        retrieved.append(ckRecord)
                    }
                } else { // nil means: we already received full response from cloud for this particular fetch
                    self.FOREGROUND() { // mutate graph
                        for record in retrieved {
                            if  self.zoneForRecordID(record.recordID) != nil {
                                if destroyedIDs.contains(record.recordID) {
                                    // self.columnarReport(" DESTROYED", child.decoratedName)

                                    break
                                }
                            }

                            let      child = self.zoneForRecord(record)

                            logic.propagateNeeds(to: child, progenyNeeded)

                            if  let parent = child.parentZone,
                                parent    != child,
                                !child.isRoot {

                                if !parent.children.contains(child) {
                                    parent.add(child)
                                    parent.respectOrder()
                                }
                            }
                        }

                        self.add(states: [.needsCount], to: childrenNeeded)
                        self.fetchChildren(logic, onCompletion) // process remaining
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

            start(operation)
        } else {
            onCompletion?(0)
        }
    }


    func establishHere(_ onCompletion: IntegerClosure?) {
        let manifest = gRemoteStoresManager.manifest(for: storageMode)

        let rootCompletion = {
            self.establishRoots { iValue in
                if iValue == 0 {
                    self.rootZone?.needProgeny()
                }

                onCompletion?(iValue)
            }
        }

        if manifest.here == nil {
            rootCompletion()
        } else {
            let recordID = manifest.here!.recordID

            self.assureRecordExists(withRecordID: recordID, recordType: zoneTypeKey) { (iHereRecord: CKRecord?) in
                if iHereRecord == nil || iHereRecord?[zoneNameKey] == nil {
                    rootCompletion()
                } else {
                    let          here = self.zoneForRecord(iHereRecord!)
                    here      .record = iHereRecord
                    manifest.hereZone = here

                    here.maybeNeedRoot()
                    here.needProgeny()
                    onCompletion?(0)
                }
            }
        }
    }


    func establishTrash(_ onCompletion: IntegerClosure?) {
        let recordID = CKRecordID(recordName: trashNameKey)

        onCompletion?(-1)

        assureRecordExists(withRecordID: recordID, recordType: zoneTypeKey) { (iRecord: CKRecord?) in
            if iRecord != nil {
                let      trash = self.zoneForRecord(iRecord!)    // get / create trash
                trash.zoneName = "trash"
                self.trashZone = trash
            }

            onCompletion?(0)
        }
    }


    func establishRoots(_ onCompletion: IntegerClosure?) {
        let recordID = CKRecordID(recordName: rootNameKey)

        onCompletion?(-1)

        assureRecordExists(withRecordID: recordID, recordType: zoneTypeKey) { (iRecord: CKRecord?) in
            if iRecord != nil {
                let      root = self.zoneForRecord(iRecord!)    // get / create root
                self.rootZone = root
            }

            self.establishTrash(onCompletion)
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
                record[property] = value as? CKRecordValue

                object.maybeNeedMerge()
            }
        }
    }


    func getFromObject(_ object: ZRecord, valueForPropertyName: String) {
        if  database != nil && object.record != nil {
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

