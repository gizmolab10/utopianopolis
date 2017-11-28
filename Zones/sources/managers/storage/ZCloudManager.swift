//
//  ZCloudManager.swift
//  Zones
//
//  Created by Jonathan Sand on 9/18/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


let gContainer = CKContainer(identifier: gCloudID)


class ZCloudManager: ZRecordsManager {
    var   cloudZonesByID = [CKRecordZoneID : CKRecordZone] ()
    var         database :  CKDatabase? { return gRemoteStoresManager.databaseForMode(storageMode) }
    var   refetchingName :       String { return "remember.\(storageMode.rawValue)" }
    var        _manifest :   ZManifest? = nil
    var currentOperation : CKOperation? = nil
    var currentPredicate : NSPredicate? = nil


    var manifest : ZManifest {
        if  _manifest == nil {
            _manifest = gRemoteStoresManager.manifest(for: storageMode)
        }

        return _manifest!
    }


    func configure(_ operation: CKDatabaseOperation) -> CKDatabaseOperation? {
        if  database != nil {
            operation.timeoutIntervalForResource = gRemoteTimeout
            operation .timeoutIntervalForRequest = gRemoteTimeout
            operation          .qualityOfService = .background
            operation                 .container = gContainer
            operation                  .database = database

            return operation
        }

        return nil
    }


    func start(_ operation: CKOperation) {
        currentOperation = operation

        BACKGROUND {     // not stall foreground processor
            operation.start()
        }
    }


    // MARK:- push to cloud
    // MARK:-


    func save(_ onCompletion: IntClosure?) {
        let   saves = pullRecordsWithMatchingStates([.needsSave])  // clears state BEFORE looking at manifest
        let destroy = recordIDsWithMatchingStates([.needsDestroy], pull: true, batchSize: 20)
        let   count = saves.count + destroy.count

        if  count > 0, let           operation = configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
            operation              .savePolicy = .allKeys
            operation       .recordIDsToDelete = destroy
            operation           .recordsToSave = saves
            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iError: Error?) in
                gAlertManager.detectError(iError) { iHasError in
                    if  iHasError {
                        let notDestroy = iRecord == nil || !destroy.contains(iRecord!.recordID)

                        if  notDestroy,
                            let     ck = iError as? CKError,
                            ck.code   == .serverRecordChanged, // oplock error
                            let record = self.recordForCKRecord(iRecord) {
                            record.maybeNeedMerge()
                        } else {
                            let message = iRecord?.description ?? ""
                            print(String(describing: iError!) + "\n" + message)
                        }
                    }
                }
            }

            operation.modifyRecordsCompletionBlock = { (iSavedCKRecords, iDeletedRecordIDs, iError) in
                // deal with saved records marked as deleted

                FOREGROUND {
                    if let deleted = iDeletedRecordIDs {
                        for recordID: CKRecordID in deleted {
                            if  let zone = self.zoneForRecordID(recordID) {
                                self.unregisterZone(zone)
                            }
                        }
                    }

                    if  let saved = iSavedCKRecords {
                        for ckrecord: CKRecord in saved {
                            if  let zone = self.zoneForRecordID(ckrecord.recordID) {
                                if  zone.isDeleted {
                                    self.unregisterZone(zone)   // unregister deleted zones
                                } else {
                                    zone.record = ckrecord
                                }
                            }
                        }
                    }

                    gAlertManager.detectError(iError, "") { iHasError in
                        if iHasError {
                            print(String(describing: iError!))
                        }
                    }

                    self.merge { iCount in                 // process merges caused (before now) by save oplock errors
                        if iCount == 0 {
                            self.save(onCompletion)         // process any remaining
                        }
                    }
                }
            }

            if   saves.count > 0 { columnarReport("SAVE \(     saves.count)", stringForCKRecords(saves)) }
            if destroy.count > 0 { columnarReport("DESTROY \(destroy.count)", stringForRecordIDs(destroy, in: storageMode)) }
            start(operation)
        } else {
            onCompletion?(0)
        }
    }


    func emptyTrash(_ onCompletion: IntClosure?) {
//        let   predicate = NSPredicate(format: "zoneIsDeleted = 1")
//        var toBeDeleted = [CKRecordID] ()
//
//        self.queryWith(predicate) { (iRecord: CKRecord?) in
//            // iRecord == nil means: end of response to this particular query
//
//            if iRecord != nil {
//                self.columnarReport("DELETE", String(describing: iRecord![gZoneNameKey]))
//                toBeDeleted.append((iRecord?.recordID)!)
//
//            } else if (toBeDeleted.count) > 0, let operation = self.configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
//                operation.recordIDsToDelete = toBeDeleted   // delete them
//                operation.completionBlock   = {
//                    onCompletion?(0)
//                }
//
//                self.start(operation)
//            } else {
//                onCompletion?(0)
//            }
//        }
    }


    func undeleteAll(_ onCompletion: IntClosure?) {
//        let predicate = NSPredicate(format: "zoneIsDeleted = 1")
//
//        onCompletion?(-1)
//
//        self.queryWith(predicate) { (iRecord: CKRecord?) in
//            if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
//                onCompletion?(0)
//            } else {
//                let            root = gRemoteStoresManager.rootZone(for: self.storageMode)
//                let         deleted = self.recordForCKRecord(iRecord) as? Zone ?? Zone(record: iRecord, storageMode: self.storageMode)
//
//                if  deleted.parent != nil {
//                    deleted.needParent()
//                } else {
//                    deleted.parentZone = root
//
//                    root?.needFetch()
//                }
//
//                deleted.maybeNeedMerge()
//                deleted.updateRecordProperties()
//            }
//        }
    }


    // MARK:- request from cloud
    // MARK:-


    func assureRecordExists(withRecordID recordID: CKRecordID, recordType: String, onCompletion: @escaping RecordClosure) {
        let done: RecordClosure = { (iCKRecord: CKRecord?) in
            FOREGROUND(canBeDirect: true) {
                onCompletion(iCKRecord)
            }
        }

        if  database == nil {
            done(nil)
        } else {
            BACKGROUND {     // not stall foreground processor
                self.database?.fetch(withRecordID: recordID) { (fetchedCKRecord: CKRecord?, fetchError: Error?) in
                    gAlertManager.alertError(fetchError) { iHasError in
                        if !iHasError {
                            done(fetchedCKRecord)
                        } else {
                            let brandNew: CKRecord = CKRecord(recordType: recordType, recordID: recordID)

                            self.database?.save(brandNew) { (savedRecord: CKRecord?, saveError: Error?) in
                                gAlertManager.detectError(saveError) { iHasError in
                                    if iHasError {
                                        done(nil)
                                    } else {
                                        done(savedRecord)
                                        gFileManager.save(to: self.storageMode)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    func queryWith(_ predicate: NSPredicate, onCompletion: RecordClosure?) {
        currentPredicate                 = predicate
        if  let                operation = configure(CKQueryOperation()) as? CKQueryOperation {
            operation             .query = CKQuery(recordType: gZoneTypeKey, predicate: predicate)
            operation       .desiredKeys = Zone.cloudProperties()
            operation      .resultsLimit = gBatchSize
            operation.recordFetchedBlock = { iRecord in
                onCompletion?(iRecord)
            }

            operation.queryCompletionBlock = { (cursor, error) in
                gAlertManager.alertError(error, predicate.description) { iHasError in
                    onCompletion?(nil) // nil means done
                }
            }

            start(operation)
        } else {
            onCompletion?(nil)
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


    func bookmarkPredicate(specificTo iRecordIDs: [CKRecordID]) -> NSPredicate {
        var  predicate    = ""

        if  iRecordIDs.count == 0 {
            predicate     = String(format: "zoneLink != '\(gNullLink)'")
        } else {
            var separator = ""

            for recordID in  iRecordIDs {
                predicate = String(format: "%@%@SELF CONTAINS \"%@\"", predicate, separator, recordID.recordName)
                separator = " AND "
            }
        }

        return NSPredicate(format: predicate)
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


    func merge(_ onCompletion: IntClosure?) {
        let recordIDs = recordIDsWithMatchingStates([.needsMerge])
        let     count = recordIDs.count

        if  count > 0, let           operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            var                    recordsByID = [CKRecord : CKRecordID?] ()
            operation               .recordIDs = recordIDs
            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                gAlertManager.detectError(iError) { iHasError in
                    if iHasError {
                        gAlertManager.alertError("MERGE ==> \(self.storageMode) \(iError!)")
                    } else if let record = iRecord {
                        recordsByID[record] = iID
                    }
                }

                self.clearStatesForRecordID(iID, forStates:[.needsMerge])
            }

            operation.completionBlock = {
                FOREGROUND {
                    if recordsByID.count == 0 {
                        for ckRecordID in recordIDs {
                            self.clearStatesForRecordID(ckRecordID, forStates: [.needsMerge])
                        }
                    } else {
                        for (iRecord, iID) in recordsByID {
                            if  let record = self.recordForRecordID(iID) {
                                record.mergeIntoAndTake(iRecord)
                            }
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


    func remember(_ onCompletion: IntClosure?) {
        BACKGROUND {     // not stall foreground processor
            var memorables = [String] ()

            let scan: ObjectClosure = { iObject in
                if let zone = iObject as? Zone {
                    zone.traverseProgeny { iZone -> (ZTraverseStatus) in
                        if  iZone.alreadyExists,
                            iZone.storageMode == self.storageMode,
                            let name = iZone.record?.recordID.recordName,
                            !memorables.contains(name) {
                            memorables.append(name)

                            if iZone.showChildren || iZone.isRoot {
                                return .eContinue
                            }
                        }

                        return .eSkip
                    }
                }
            }

            scan(self.rootZone)
            scan(self.manifest.hereZone)
            scan(gFavoritesManager.rootZone)

            self.columnarReport("REMEMBER \(memorables.count)", "\(self.storageMode.rawValue)")
            setString(memorables.joined(separator: gSeparatorKey), for: self.refetchingName)
            onCompletion?(0)
        }
    }


    func refetch(_ onCompletion: IntClosure?) {
        if  let fetchables = getString(for: refetchingName, defaultString: "")?.components(separatedBy: gSeparatorKey) {
            let   fetching = [ZRecordState.needsFetch]

            for fetchable in fetchables {
                if fetchable != "" {
                    addCKRecord(CKRecord(for: fetchable), for: fetching)
                }
            }

            fetch(onCompletion)
        }
    }


    func fetchTrash(_ onCompletion: IntClosure?) {
        if  let     trash = trashZone {
            let parentKey = "parent"
            let predicate = NSPredicate(format: "zoneName != \"\"")
            let rootNames = [gRootNameKey, gTrashNameKey, gFavoriteRootNameKey]
            var retrieved = [CKRecord] ()

            self.queryWith(predicate) { (iRecord: CKRecord?) in
                if  let ckRecord = iRecord, !retrieved.contains(ckRecord) {
                    if  let name = ckRecord[gZoneNameKey] as? String,
                        !rootNames.contains(name) {
                        retrieved.append(ckRecord)
                    }
                } else { // nil means: we already received full response from cloud for this particular fetch
                    FOREGROUND {
                        var    parentIDs = [CKRecordID] ()
                        var childrenRefs = [CKRecordID : CKRecord] ()

                        for ckRecord in retrieved {
                            if  let parent   = ckRecord[parentKey] as? CKReference {
                                let parentID = parent.recordID
                                if  self.recordForRecordID(parent.recordID) == nil,
                                    !rootNames.contains(parent.recordID.recordName) {
                                    childrenRefs[parentID] = ckRecord

                                    parentIDs.append(parent.recordID)
                                } // else it's already in memory (either the trash or the graph)
                            } else if let name = ckRecord[gZoneNameKey] as? String,
                                ![gRootNameKey, gTrashNameKey, gFavoriteRootNameKey].contains(name),
                                let added = trash.addCKRecord(ckRecord) {
                                added.needSave()
                                trash.needSave()
                            }
                        }

                        let count = parentIDs.count

                        if count == 0 {
                            onCompletion?(0)
                        } else {
                            var  destroy = [CKRecord] ()
                            var tracking = [CKRecordID] ()
                            var  closure:  RecordIDsClosure? = nil

                            closure = { iParentIDs in
                                var missing = iParentIDs

                                for recordID in tracking {
                                    if  let index = missing.index(of: recordID) {
                                        missing.remove(at: index)
                                    }
                                }

                                tracking.append(contentsOf: missing)

                                // ask cloud if referenced zone exists
                                // do the same with its parent
                                // until doesn't exist
                                // then add to trash

                                self.fetch(needed: missing) { iRetrievedParents in
                                    parentIDs = []

                                    for ckParent in iRetrievedParents {
                                        if  let index = ckParent.index(within: missing) {
                                            missing.remove(at: index)

                                            if  let grandParentRef = ckParent[parentKey] as? CKReference {
                                                parentIDs.append(grandParentRef.recordID)
                                            }
                                        } else {
                                            destroy.append(ckParent)
                                        }
                                    }

                                    if missing.count != 0 {
                                        for parent in missing {
                                            if  let    child = childrenRefs[parent] {
//                                                if  let name = child[gZoneNameKey] as? String {
//                                                    self.columnarReport(" MISSING", name)
//                                                }
                                                
                                                if let added = trash.addCKRecord(child) {
                                                    added.needSave()
                                                    trash.needSave()
                                                }
                                            }
                                        }
                                    }

//                                    if destroy.count != 0 {
//                                        for ckRecord in destroy {}
//                                        self.columnarReport(" DESTROY?", self.stringForCKRecords(destroy))
//                                    }

                                    let evokeClosure = parentIDs.count != 0

                                    if  evokeClosure {
                                        closure?(parentIDs)
                                    } else {
                                        onCompletion?(0)
                                    }
                                }
                            }

                            closure?(parentIDs)
                        }
                    }
                }
            }
        } else {
            onCompletion?(0)
        }
    }


    func fetch(_ onCompletion: IntClosure?) {
        let states = [ZRecordState.needsFetch]
        let needed = recordIDsWithMatchingStates(states)

        fetch(needed: needed) { iCKRecords in
            FOREGROUND {
                if iCKRecords.count == 0 {
                    onCompletion?(0)
                } else {
                    for ckRecord in iCKRecords {
                        var record  = self.recordForCKRecord(ckRecord)

                        if  record == nil {
                            record  = ZRecord(record: ckRecord, storageMode: self.storageMode)
                        } else {
                            record?.record = ckRecord
                        }

                        record?.unorphan()
                    }

                    self.clearCKRecords(iCKRecords, for: states)    // deferred to make sure fetch worked before clearing fetch flag
                    self.columnarReport("FETCH \(iCKRecords.count)", self.stringForCKRecords(iCKRecords))
                    self.fetch(onCompletion)                        // process remaining
                }
            }
        }
    }


    func fetch(needed: [CKRecordID], _ onCompletion: RecordsClosure?) {
        let count = needed.count

        if  count > 0, let operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            var            retrieved = [CKRecord] ()
            operation   .desiredKeys = Zone.cloudProperties()
            operation     .recordIDs = needed

            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                gAlertManager.alertError(iError) { iHasError in
                    if  iHasError {
                        print("ack!")
                    } else if let ckRecord = iRecord,
                        !retrieved.contains(ckRecord) {
                        retrieved.append(ckRecord)
                    }
                }
            }

            operation.completionBlock = {
                onCompletion?(retrieved)
            }

            start(operation)
        } else {
            onCompletion?([])
        }
    }



    func fetchManifest(_ onCompletion: IntClosure?) {
        if  manifest.alreadyExists || manifest.isMarkedForAnyOfStates([.needsMerge, .needsSave]) {
            onCompletion?(0)
        } else {
            let recordID = manifest.record.recordID
            let     mine = gRemoteStoresManager.cloudManagerFor(.mineMode)

            mine.assureRecordExists(withRecordID: recordID, recordType: gManifestTypeKey) { (iManifestRecord: CKRecord?) in
                if  iManifestRecord     != nil {
                    self.manifest.record = iManifestRecord

                    if  let         here = self.manifest.here,
                        let         mode = self.manifest.manifestMode {
                        let   identifier = CKRecordID(recordName: here)
                        let        cloud = gRemoteStoresManager.cloudManagerFor(mode)

                        cloud.assureRecordExists(withRecordID: identifier, recordType: gZoneTypeKey) { iCKRecord in
                            self.manifest._hereZone = Zone(record: iCKRecord, storageMode: mode)

                            onCompletion?(0)
                        }
                    } else {
                        onCompletion?(0)
                    }
                }
            }
        }
    }


    func fetchParents(_ onCompletion: IntClosure?) {
        let states: [ZRecordState] = [.needsWritable, .needsParent, .needsColor, .needsRoot]
        let         missingParents = parentIDsWithMatchingStates(states)
        let                orphans = recordIDsWithMatchingStates(states)
        let                  count = missingParents.count

        if  count > 0, let operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            var        recordsByID = [CKRecord : CKRecordID?] ()
            operation   .recordIDs = missingParents

            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                gAlertManager.alertError(iError) { iHasError in
                    if  !iHasError, iRecord != nil {
                        recordsByID[iRecord!] = iID
                    }
                }
            }

            operation.completionBlock = {
                FOREGROUND {
                    var forReport = [Zone] ()

                    for (iRecord, iID) in recordsByID {
                        var fetchedParent  = self.zoneForRecordID(iID)

                        if  fetchedParent != nil {
                            fetchedParent?.mergeIntoAndTake(iRecord) // BROKEN: likely this does not do what's needed here .... yikes! HUH?
                        } else {
                            fetchedParent  = self.zoneForRecord(iRecord)
                        }

                        if  let         p = fetchedParent {
                            let fetchedID = p.record.recordID

                            for orphan in orphans {
                                if  let  child = self.zoneForRecordID(orphan), let parentID = child.parentZone?.record.recordID, parentID == fetchedID {
                                    let states = self.states(for: child.record)

                                    if  child.isRoot || child == p {
                                        child.parentZone = nil

                                        child.needSave()
                                    } else if !p.children.contains(child) {
                                        p.children.append(child)
                                    }

                                    if !forReport.contains(child) {
                                        forReport.append(child)
                                    }

                                    if  states.contains(.needsRoot) {
                                        p.maybeNeedRoot()
                                    }

                                    if  states.contains(.needsColor) {
                                        p.maybeNeedColor()
                                    }

                                    if  states.contains(.needsWritable) {
                                        p.maybeNeedWritable()
                                    }

                                    p.maybeNeedChildren()
                                }
                            }
                        }
                    }
                    
                    self.columnarReport("PARENT of", self.stringForZones(forReport))
                    self.clearRecordIDs(orphans, for: states)
                    self.fetchParents(onCompletion)   // process remaining
                }
            }

            start(operation)
        } else {
            onCompletion?(0)
        }
    }


    func fetchChildren(_ iLogic: ZRecursionLogic? = ZRecursionLogic(.restore), _ onCompletion: IntClosure?) {
        let          logic = iLogic              ?? ZRecursionLogic(.restore)
        let  progenyNeeded = pullReferencesWithMatchingStates([.needsProgeny])
        let childrenNeeded = pullReferencesWithMatchingStates([.needsChildren]) + progenyNeeded
        let   destroyedIDs = recordIDsWithMatchingStates([.needsDestroy])
        let          count = childrenNeeded.count

        onCompletion?(count)

        if count > 0 {
            var  retrieved = [CKRecord] ()
            let  predicate = NSPredicate(format: "parent IN %@", childrenNeeded)

            queryWith(predicate) { (iRecord: CKRecord?) in
                if  let ckRecord = iRecord {
                    if !retrieved.contains(ckRecord) {
                        retrieved.append(ckRecord)
                    }
                } else { // nil means: we already received full response from cloud for this particular fetch
                    FOREGROUND {

                        ////////////////////////////
                        // now we can mutate heap //
                        ////////////////////////////

                        for record in retrieved {
                            let     identifier = record.recordID

                            if destroyedIDs.contains(identifier) {
                                // self.columnarReport(" DESTROYED", child.decoratedName)
                            } else {
                                let    fetched = self.zoneForRecord(record)
                                let     parent = fetched.parentZone
                                let extraTrash = fetched.zoneLink == gTrashLink && parent?.isRootOfFavorites ?? false && gFavoritesManager.hasTrash

                                if  fetched.isRoot {
                                    fetched.parent = nil  // avoids HANG ... a root can NOT be a child, by definition
                                } else if fetched == parent || extraTrash {
                                    fetched.needDestroy()
                                    // self-parenting causes infinite recursion AND extra trash favorites are annoying
                                    // destroy either on fetch
                                } else {
                                    logic.propagateNeeds(to: fetched, progenyNeeded)

                                    if  let p = parent,
                                        !p.hasChildMatchingRecordName(of: fetched) {

                                        ///////////////////////////////////////
                                        // no child has matching record name //
                                        ///////////////////////////////////////

                                        if  let target = fetched.bookmarkTarget {

                                            ///////////////////////////////////////////////////////////
                                            // bookmark targets need color, writable and maybe fetch //
                                            ///////////////////////////////////////////////////////////

                                            if !target.alreadyExists {
                                                target.needFetch()
                                            }

                                            target.maybeNeedWritable()
                                            target.maybeNeedColor()
                                        }

                                        p.add(fetched)
                                        p.respectOrder()
                                    }
                                }
                            }
                        }

                        self.columnarReport("CHILDREN of", self.stringForReferences(childrenNeeded, in: self.storageMode))
                        self.add(states: [.needsCount], to: childrenNeeded)
                        self.fetchChildren(logic, onCompletion) // process remaining
                    }
                }
            }
        }
    }


    func fetchBookmarks(_ onCompletion: IntClosure?) {
        let targetIDs = recordIDsWithMatchingStates([.needsBookmarks], pull: true)
        let predicate = bookmarkPredicate(specificTo: targetIDs)
        var retrieved = [CKRecord] ()

        queryWith(predicate) { iRecord in
            if let ckRecord = iRecord {
                if !retrieved.contains(ckRecord) {
                    retrieved.append(ckRecord)
                }
            } else { // nil means done
                FOREGROUND {
                    var     gotFresh = false

                    for ckRecord in retrieved {
                        var zRecord  = self.recordForCKRecord(ckRecord)

                        if  zRecord == nil {                                                 // if not already registered
                            zRecord  = Zone(record: ckRecord, storageMode: self.storageMode) // register
                            gotFresh = true
                        }

                        zRecord?.unorphan()
                    }

                    if  targetIDs.count != 0 {
                        for recordID in targetIDs {
                            let  zRecord = self.recordForRecordID(recordID)

                            zRecord?.unmarkForAllOfStates([.needsBookmarks])
                            zRecord?.unorphan()
                        }

                        if retrieved.count > 0 {
                            self.columnarReport("BOOKMARKS", self.stringForCKRecords(retrieved))
                        }

                        self.fetchBookmarks(onCompletion)       // process remaining
                    } else if gotFresh {
                        self.save { iCount in                   // no-op if no zones need to be saved, in which case falls through ...
                            self.fetchBookmarks(onCompletion)   // process remaining
                        }
                    } else {
                        onCompletion?(0)
                    }
                }
            }
        }
    }


    func fetchCloudZones(_ onCompletion: IntClosure?) {
        if let                              operation = configure(CKFetchRecordZonesOperation()) as? CKFetchRecordZonesOperation {
            operation.fetchRecordZonesCompletionBlock = { (recordZonesByZoneID, operationError) in
                self.cloudZonesByID                   = recordZonesByZoneID!

                gRemoteStoresManager.resetBadgeCounter()

                onCompletion?(0)
            }

            start(operation)
            onCompletion?(-1)
        } else {
            onCompletion?(0)
        }
    }


    func establishHere(_ onCompletion: IntClosure?) {
        let rootCompletion = {
            self.manifest.hereZone = gRoot!

            onCompletion?(0)
        }

        if manifest.here == nil { // first time user
            rootCompletion()
        } else {
            let recordID = CKRecordID(recordName: manifest.here!)

            self.assureRecordExists(withRecordID: recordID, recordType: gZoneTypeKey) { (iHereRecord: CKRecord?) in
                if iHereRecord == nil || iHereRecord?[gZoneNameKey] == nil {
                    rootCompletion()
                } else {
                    let               here = self.zoneForRecord(iHereRecord!)
                    here           .record = iHereRecord
                    self.manifest.hereZone = here

                    here.maybeNeedRoot()
                    onCompletion?(0)
                }
            }
        }
    }


    func establishRoot(_ onCompletion: IntClosure?) {
        if rootZone != nil {
            establishTrash(onCompletion)
        } else {
            let recordID = CKRecordID(recordName: gRootNameKey)

            assureRecordExists(withRecordID: recordID, recordType: gZoneTypeKey) { (iRecord: CKRecord?) in
                var ckRecord  = iRecord
                if  ckRecord == nil {
                    ckRecord  = CKRecord(recordType: gZoneNameKey, recordID: recordID)
                }

                self.rootZone = self.zoneForRecord(ckRecord!)    // get / create root7

                if  self.rootZone?.zoneName == nil {
                    self.rootZone?.zoneName = "title"
                }

                self.rootZone?.needSave()
                self.establishTrash(onCompletion)
            }
        }
    }


    func establishTrash(_ onCompletion: IntClosure?) {
        if trashZone != nil {
            onCompletion?(0)
        } else {
            let recordID = CKRecordID(recordName: gTrashNameKey)

            assureRecordExists(withRecordID: recordID, recordType: gZoneTypeKey) { (iRecord: CKRecord?) in
                if iRecord != nil {
                    let      trash = self.zoneForRecord(iRecord!)    // get / create trash
                    trash.zoneName = gTrashNameKey
                    self.trashZone = trash
                }

                onCompletion?(0)
            }
        }
    }


    // MARK:- remote persistence
    // MARK:-


    func unsubscribe(_ onCompletion: IntClosure?) {
        if  database == nil {
            onCompletion?(0)
        } else {
            onCompletion?(-1)
            database!.fetchAllSubscriptions { (iSubscriptions: [CKSubscription]?, iError: Error?) in
                gAlertManager.alertError(iError) { iHasError in
                    if iHasError {
                        onCompletion?(0)
                    } else {
                        var count: Int = iSubscriptions!.count

                        if count == 0 {
                            onCompletion?(0)
                        } else {
                            for subscription: CKSubscription in iSubscriptions! {
                                self.database!.delete(withSubscriptionID: subscription.subscriptionID, completionHandler: { (iSubscription: String?, iUnsubscribeError: Error?) in
                                    gAlertManager.alertError(iUnsubscribeError) { iHasError in }

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


    func subscribe(_ onCompletion: IntClosure?) {
        if  database == nil {
            onCompletion?(0)
        } else {
            let classNames = [gZoneTypeKey, gManifestTypeKey]
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
                    gAlertManager.alertError(iSubscribeError) { iHasError in
                        if iHasError {
                            self.signalFor(iSubscribeError as NSObject?, regarding: .error)
                        }
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
        if  database          != nil &&
            object    .record != nil {
            let      predicate = NSPredicate(value: true)
            let  type: String  = NSStringFromClass(type(of: object)) as String
            let query: CKQuery = CKQuery(recordType: type, predicate: predicate)

            database?.perform(query, inZoneWith: nil) { (iResults: [CKRecord]?, performanceError: Error?) in
                gAlertManager.detectError(performanceError) { iHasError in
                    if iHasError {
                        self.signalFor(performanceError as NSObject?, regarding: .error)
                    } else {
                        let                record: CKRecord = (iResults?[0])!
                        object.record[valueForPropertyName] = (record as! CKRecordValue)

                        self.signalFor(nil, regarding: .redraw)
                    }
                }
            }
        }
    }
}

