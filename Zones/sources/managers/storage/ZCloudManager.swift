//
//  ZCloudManager.swift
//  Zones
//
//  Created by Jonathan Sand on 9/18/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


let gContainer = CKContainer(identifier: kCloudID)


class ZCloudManager: ZRecordsManager {
    var   cloudZonesByID = [CKRecordZoneID : CKRecordZone] ()
    var         database :  CKDatabase? { return gRemoteStoresManager.databaseForID(databaseID) }
    var   refetchingName :       String { return "remember.\(databaseID.rawValue)" }
    var currentOperation : CKOperation? = nil
    var currentPredicate : NSPredicate? = nil
    var    isRemembering :         Bool = false


    func configure(_ operation: CKDatabaseOperation) -> CKDatabaseOperation? {
        if  database != nil {
            operation.timeoutIntervalForResource = kRemoteTimeout
            operation .timeoutIntervalForRequest = kRemoteTimeout
            operation          .qualityOfService = .background
            operation                 .container = gContainer

            return operation
        }

        return nil
    }


    func start(_ operation: CKDatabaseOperation) {
        currentOperation = operation

        BACKGROUND {     // not stall foreground processor
            self.database?.add(operation)
        }
    }


    // MARK:- push to cloud
    // MARK:-


    func save(_ onCompletion: IntClosure?) {
        let   saves = pullCKRecordsWithMatchingStates([.needsSave])
        let destroy = pullRecordIDsWithHighestLevel(for: [.needsDestroy], batchSize: 20)
        let   count = saves.count + destroy.count

        if  count > 0, let           operation = configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
            operation              .savePolicy = .allKeys
            operation           .recordsToSave = saves
            operation       .recordIDsToDelete = destroy
            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iError: Error?) in
                let                 notDestroy = iRecord == nil || !destroy.contains(iRecord!.recordID)
                gAlertManager.detectError(iError) { iHasError in
                    if  iHasError {
                        if  notDestroy,
                            let     ck = iError as? CKError,
                            ck.code   == .serverRecordChanged, // oplock error
                            let record = self.maybeZRecordForCKRecord(iRecord) {
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
                    if  let destroyed = iDeletedRecordIDs {
                        for recordID: CKRecordID in destroyed {
                            if  let zRecord = self.maybeZRecordForRecordID(recordID) { // zones AND traits
                                zRecord.orphan()
                                self.unregisterZRecord(zRecord)
                            }
                        }
                    }

                    if  let saved = iSavedCKRecords {
                        for ckRecord: CKRecord in saved {
                            if  let zone = self.maybeZoneForRecordID(ckRecord.recordID) {
                                zone.useBest(record: ckRecord)
                                ckRecord.maybeMarkAsFetched(self.databaseID)
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

            if   saves.count > 0 { columnarReport("SAVE (\(     saves.count))", stringForCKRecords(saves)) }
            if destroy.count > 0 { columnarReport("DESTROY (\(destroy.count))", stringForRecordIDs(destroy)) }

            start(operation)
        } else {
            onCompletion?(0)
        }
    }


    func emptyTrash(_ onCompletion: IntClosure?) {
//        let   predicate = NSPredicate(format: "zoneisInTrash = 1")
//        var toBeDeleted = [CKRecordID] ()
//
//        self.queryWith(predicate) { (iRecord: CKRecord?) in
//            // iRecord == nil means: end of response to this particular query
//
//            if iRecord != nil {
//                self.columnarReport("DELETE", String(describing: iRecord![pZoneName]))
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
//        let predicate = NSPredicate(format: "zoneisInTrash = 1")
//
//        onCompletion?(-1)
//
//        self.queryWith(predicate) { (iRecord: CKRecord?) in
//            if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
//                onCompletion?(0)
//            } else {
//                let            root = gRemoteStoresManager.rootZone(for: self.databaseID)
//                let         deleted = self.maybeZRecordForCKRecord(iRecord) as? Zone ?? Zone(record: iRecord, databaseID: self.databaseID)
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


    func assureRecordExists(withRecordID iCKRecordID: CKRecordID, recordType: String, onCompletion: @escaping RecordClosure) {
        let done:  RecordClosure = { (iCKRecord: CKRecord?) in
            FOREGROUND(canBeDirect: true) {
                if  let ckRecord = iCKRecord {
                    ckRecord.maybeMarkAsFetched(self.databaseID)
                }

                onCompletion(iCKRecord)
            }
        }

        if      database    == nil,
                gFetchMode  == .localOnly {
            if  gFetchMode  == .localOnly,
                let ckRecord = maybeCKRecordForRecordName(iCKRecordID.recordName),
                !hasCKRecordName(iCKRecordID.recordName, forAnyOf: [.notFetched]) {
                done(ckRecord)
            }

            done(nil)
        } else {
            BACKGROUND {     // not stall foreground processor
                self.database?.fetch(withRecordID: iCKRecordID) { (iFetchedCKRecord: CKRecord?, iFetchError: Error?) in
                    gAlertManager.alertError(iFetchError) { iHasError in
                        if !iHasError {
                            done(iFetchedCKRecord)
                        } else {
                            let brandNew: CKRecord = CKRecord(recordType: recordType, recordID: iCKRecordID)

                            self.database?.save(brandNew) { (iSavedRecord: CKRecord?, iSaveError: Error?) in
                                gAlertManager.detectError(iSaveError) { iHasSaveError in
                                    if  iHasSaveError {
                                        done(nil)
                                    } else {
                                        done(iSavedRecord)
                                        gFileManager.write(for: self.databaseID)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    func queryWith(_ predicate: NSPredicate, recordType: String, properties: [String], batchSize: Int = kBatchSize, onCompletion: RecordClosure?) {
        currentPredicate                 = predicate
        if  let                operation = configure(CKQueryOperation()) as? CKQueryOperation {
            operation             .query = CKQuery(recordType: recordType, predicate: predicate)
            operation       .desiredKeys = properties
            operation      .resultsLimit = batchSize
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


    func queryWith(_ predicate: NSPredicate, batchSize: Int = kBatchSize, onCompletion: RecordClosure?) {
        queryWith(predicate, recordType: kZoneType, properties: Zone.cloudProperties(), batchSize: batchSize, onCompletion: onCompletion)
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


    func traitsPredicate(specificTo iRecordIDs: [CKRecordID]) -> NSPredicate? {
        if  iRecordIDs.count == 0 {
            return gReadyState ? nil : NSPredicate(value: true)
        } else {
            var predicate = ""
            var separator = ""

            for recordID in iRecordIDs {
                predicate = String(format: "%@%@SELF CONTAINS \"%@\"", predicate, separator, recordID.recordName)
                separator = " AND "
            }

            return NSPredicate(format: predicate)
        }
    }


    func bookmarkPredicate(specificTo iRecordIDs: [CKRecordID]) -> NSPredicate {
        var  predicate    = ""

        if  iRecordIDs.count == 0 {
            predicate     = String(format: "zoneLink != '\(kNullLink)'")
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
        var recordIDs = recordIDsWithMatchingStates([.needsMerge])
        let     count = recordIDs.count

        if  count > 0, let           operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            var                    recordsByID = [CKRecord : CKRecordID?] ()
            operation               .recordIDs = recordIDs
            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                gAlertManager.detectError(iError) { iHasError in
                    if  iHasError {
                        let    zone = self.maybeZoneForRecordID(iID)
                        let message = zone == nil ? String(describing: iError) : zone?.unwrappedName

                        gAlertManager.alertError("MERGE within \(self.databaseID) \(message!)")

                        if let id = iID, let index = recordIDs.index(of: id) {
                            recordIDs.remove(at: index)
                        }
                    } else if let record = iRecord {
                        recordsByID[record] = iID
                    }
                }

                self.clearRecordName(iID?.recordName, for:[.needsMerge])
            }

            operation.completionBlock = {
                FOREGROUND {
                    if  recordsByID.count == 0 {
                        for ckRecordID in recordIDs {
                            self.clearRecordName(ckRecordID.recordName, for: [.needsMerge])
                        }
                    } else {
                        for (iRecord, iID) in recordsByID {
                            if  let zRecord = self.maybeZRecordForRecordID(iID) {
                                zRecord.useBest(record: iRecord)
                            }
                        }
                    }

                    self.merge(onCompletion)        // process remaining
                }
            }
            
            self.columnarReport("MERGE (\(recordIDs.count))", stringForRecordIDs(recordIDs))
            start(operation)
        } else {
            onCompletion?(0)
        }
    }


    // MARK:- fetch
    // MARK:-


    func remember(_ onCompletion: IntClosure?) {
        if  isRemembering {
            onCompletion?(0)
        } else {
            isRemembering = true

            BACKGROUND {     // not stall foreground processor
                var memorables = [String] ()

                let scan: ObjectClosure = { iObject in
                    if let zone = iObject as? Zone {
                        zone.traverseAllProgeny { iZone in
                            if  iZone.isFetched,
                                iZone.databaseID == self.databaseID,
                                let identifier = iZone.recordName,
                                !iZone.isRoot,
                                !memorables.contains(identifier) {
                                memorables.append(identifier)
                            }
                        }
                    }
                }

                scan(self.rootZone)
                scan(gHere)
                scan(gFavoritesManager.rootZone)

                self.columnarReport("REMEMBER (\(memorables.count))", "\(self.databaseID.rawValue)")
                setPreferencesString(memorables.joined(separator: kSeparator), for: self.refetchingName)

                self.isRemembering = false

                onCompletion?(0)
            }
        }
    }


    func refetchZones(_ onCompletion: IntClosure?) {
        if  let fetchables = getPreferencesString(for: refetchingName, defaultString: "")?.components(separatedBy: kSeparator) {
            for fetchable in fetchables {
                if fetchable != "" {
                    addCKRecord(CKRecord(for: fetchable), for: [.needsFetch])
                }
            }

            fetchZones(onCompletion) // includes processing logic for retrieved records
        }
    }


    func fetchLost(_ onCompletion: IntClosure?) {
        let    format = kpRecordName + " != \"" + kRootName + "\""
        let predicate = NSPredicate(format: format)
        var   fetched = [CKRecord] ()

        self.queryWith(predicate, batchSize: kMaxBatchSize) { iRecord in
            if  let ckRecord      = iRecord {
                if  !kAutoGeneratedNames.contains(ckRecord.recordID.recordName),
                    !fetched.contains(ckRecord) {
                    fetched.append(ckRecord)
                }
            } else { // nil means: we already received full response from cloud for this particular fetch
                FOREGROUND {
                    let          parentKey = "parent"
                    let      parentLinkKey = "parentLink"
                    var               lost = self.createRandomLost()
                    var          parentIDs = [CKRecordID] ()
                    var             toLose = [CKRecord] ()
                    var childrenRecordsFor = [CKRecordID : [CKRecord]] ()
                    let         isOrphaned = { (iCKRecord: CKRecord) -> Bool in
                        if  let  parentRef = iCKRecord[parentKey] as? CKReference {
                            let  parentID  = parentRef.recordID

                            if  self.notRegistered(parentID) {
                                parentIDs.append(parentID)

                                if  childrenRecordsFor[parentID] == nil {
                                    childrenRecordsFor[parentID]  = []
                                }

                                childrenRecordsFor[parentID]?.append(iCKRecord)
                            }

                            return false
                        } else if let parentLink = iCKRecord[parentLinkKey] as? String, self.name(from: parentLink) != nil {
                            return false // parent is in other db, therefore it can't be verified as lost
                        }

                        return true
                    }

                    let addToLost: RecordsClosure = { iCKRecords in
                        if iCKRecords.count > 0 {
                            self.columnarReport("  FOUND (\(iCKRecords.count))", self.stringForCKRecords(iCKRecords))
                            for ckRecord in iCKRecords {
                                lost.addChild(for: ckRecord)

                                if  lost.count > 30 {
                                    lost = self.createRandomLost()
                                }
                            }
                        }
                    }

                    for ckRecord in fetched {
                        if isOrphaned(ckRecord) {
                            toLose.append(ckRecord)
                        }
                    }

                    addToLost(toLose)

                    if childrenRecordsFor.count == 0 {
                        onCompletion?(0)
                    } else {
                        var missingIDs = [CKRecordID] ()
                        var fetchClosure : Closure? = nil
                        
                        fetchClosure = {
                            if  parentIDs.count == 0 {
                                onCompletion?(0)
                            } else {
                                var seekParentIDs = parentIDs

                                for recordID in missingIDs {
                                    if  let index = seekParentIDs.index(of: recordID) {
                                        seekParentIDs.remove(at: index)
                                    }
                                }

                                missingIDs.append(contentsOf: seekParentIDs)

                                // ask cloud if parentIDs exist
                                // do the same with parent's parent
                                // until doesn't exist
                                // add each parentless ancestor to lost

                                self.fetchZones(needed: seekParentIDs) { iFetchedParents in
                                    parentIDs = []
                                    toLose    = []

                                    self.columnarReport("  FETCHED (\(iFetchedParents.count))", self.stringForCKRecords(iFetchedParents))
                                    for ckParent in iFetchedParents {
                                        if  let index = seekParentIDs.index(of: ckParent.recordID) {
                                            seekParentIDs.remove(at: index)

                                            if isOrphaned(ckParent) {}
                                        }
                                    }

                                    for parentID in seekParentIDs {
                                        if  let children = childrenRecordsFor[parentID] {
                                            toLose.append(contentsOf: children)

                                            childrenRecordsFor[parentID] = nil
                                        }
                                    }

                                    FOREGROUND {
                                        addToLost(toLose)

//                                        onCompletion?(0)
                                        fetchClosure?()
                                    }
                                }
                            }
                        }
                        
                        fetchClosure?()
                    }
                }
            }
        }
    }


    func fetchZones(_ onCompletion: IntClosure?) {
        let needed = recordIDsWithMatchingStates([.needsFetch, .requiresFetch], pull: true)

        fetchZones(needed: needed) { iCKRecords in
            FOREGROUND {
                if iCKRecords.count == 0 {
                    onCompletion?(0)
                } else {
                    for ckRecord in iCKRecords {
                        var zRecord  = self.maybeZRecordForRecordName(ckRecord.recordID.recordName)

                        if  zRecord == nil {
                            zRecord  = Zone(record: ckRecord, databaseID: self.databaseID)
                        } else {
                            zRecord?.useBest(record: ckRecord)
                        }

                        zRecord?.maybeNeedRoot()
                        zRecord?.needChildren()
                    }

                    self.columnarReport("FETCH (\(iCKRecords.count))", self.stringForCKRecords(iCKRecords))
                    self.unorphanAll()
                    self.fetchZones(onCompletion)                            // process remaining
                }
            }
        }
    }


    func fetchZones(needed:  [CKRecordID], _ onCompletion: RecordsClosure?) {
        var recordIDs = [CKRecordID] ()
        var retrieved = [CKRecord] ()
        var remainder = needed
        var fetchClosure : Closure? = nil

        fetchClosure = {
            let count = remainder.count
            recordIDs = remainder

            if  count == 0 {
                onCompletion?(retrieved)
            } else {
                if  count <= kBatchSize {
                    remainder = []
                } else {
                    recordIDs.removeSubrange(kBatchSize ..< count)
                    remainder.removeSubrange(0 ..< kBatchSize)
                }

                self.reliableFetch(needed: recordIDs) { iCKRecords in
                    retrieved.append(contentsOf: iCKRecords)
                    fetchClosure?()
                }
            }
        }

        fetchClosure?()
    }


    func reliableFetch(needed: [CKRecordID], _ onCompletion: RecordsClosure?) {
        let count = needed.count

        if  count > 0, let operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            var            retrieved = [CKRecord] ()
            operation   .desiredKeys = Zone.cloudProperties()
            operation     .recordIDs = needed

            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                gAlertManager.alertError(iError) { iHasError in
                    if  iHasError {
                        if  let bad = self.maybeZoneForRecordID(iID) {
                            bad.unregister()    // makes sure we do not save it to cloud
                        } else {
                            self.clearRecordName(iID?.recordName, for: [.needsFetch])
                        }
                    } else if let ckRecord = iRecord,
                        !retrieved.contains(ckRecord) {
                        retrieved.append(ckRecord)
                        self.clearRecordName(ckRecord.recordID.recordName, for:[.requiresFetch, .needsFetch])
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


    func fetchParents(_ onCompletion: IntClosure?) {
        let fetchingStates: [ZRecordState] = [.needsWritable, .needsParent, .needsColor, .needsRoot]
        let               missingParentIDs = parentIDsWithMatchingStates(fetchingStates)
        let                    childrenIDs = recordIDsWithMatchingStates(fetchingStates)
        let                          count = missingParentIDs.count

        if  count > 0, let       operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            var         fetchedRecordsByID = [CKRecord : CKRecordID?] ()
            operation           .recordIDs = missingParentIDs

            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                gAlertManager.alertError(iError) { iHasError in
                    if  !iHasError, iRecord != nil {
                        fetchedRecordsByID[iRecord!] = iID
                    }
                }
            }

            operation.completionBlock = {
                FOREGROUND {
                    var forReport  = [Zone] ()

                    for (fetchedRecord, fetchedID) in fetchedRecordsByID {
                        var maybe  = self.maybeZoneForRecordID(fetchedID)
                        if  maybe != nil {
                            maybe?.useBest(record: fetchedRecord)
                        } else {
                            maybe  = self.zoneForCKRecord(fetchedRecord)
                        }

                        if  let    fetched = maybe,     // always not nil
                            let recordName = fetched.recordName {

                            fetched.maybeNeedChildren()

                            for childID in childrenIDs {
                                if  let   child = self.maybeZoneForRecordID(childID), !fetched.spawnedBy(child),
                                    recordName == child.parentZone?.recordName {
                                    let  states = self.states(for: child.record)

                                    if  child.isRoot || child == fetched {
                                        child.parentZone = nil

                                        child.maybeNeedSave()
                                    } else if !fetched.children.contains(child) {
                                        fetched.children.append(child)
                                    }

                                    if !forReport.contains(child) {
                                        forReport.append(child)
                                    }

                                    if  states.contains(.needsRoot) {
                                        fetched.maybeNeedRoot()
                                        fetched.needChildren()
                                    }

                                    if  states.contains(.needsColor) {
                                        fetched.maybeNeedColor()
                                    }

                                    if  states.contains(.needsWritable) {
                                        fetched.maybeNeedWritable()
                                    }
                                }
                            }
                        }
                    }
                    
                    self.columnarReport("PARENT (\(forReport.count)) of", self.stringForZones(forReport))
                    self.clearRecordIDs(childrenIDs, for: fetchingStates)
                    self.unorphanAll()
                    self.fetchParents(onCompletion)   // process remaining
                }
            }

            start(operation)
        } else {
            onCompletion?(0)
        }
    }


    func fetchChildren(_ onCompletion: IntClosure?) {
        let childrenNeeded = childrenRefsWithMatchingStates([.needsChildren, .needsProgeny], batchSize: kSmallBatchSize)
        let          count = childrenNeeded.count

        onCompletion?(count)

        if count > 0 {
            let      predicate = NSPredicate(format: "parent IN %@", childrenNeeded)
            let   destroyedIDs = recordIDsWithMatchingStates([.needsDestroy])
            var  progenyNeeded = [CKReference] ()
            var      retrieved = [CKRecord] ()

            if hasAnyRecordsMarked(with: [.needsProgeny]) {
                for reference in childrenNeeded {
                    let identifier = reference.recordID

                    if  registeredCKRecordForID(identifier, forAnyOf: [.needsProgeny]) != nil && !progenyNeeded.contains(reference) {
                        progenyNeeded.append(reference)
                    }
                }
            }

            clearReferences(childrenNeeded, for: [.needsChildren, .needsProgeny])

            queryWith(predicate, batchSize: kMaxBatchSize) { (iRecord: CKRecord?) in
                if  let ckRecord = iRecord {
                    if !retrieved.contains(ckRecord) {
                        retrieved.append(ckRecord)
                    }
                } else { // nil means: we already received full response from cloud for this particular fetch
                    FOREGROUND {

                        ////////////////////////////
                        // now we can mutate heap //
                        ////////////////////////////

                        for childRecord in retrieved {
                            let     identifier = childRecord.recordID

                            if destroyedIDs.contains(identifier) {
                                // self.columnarReport(" DESTROYED", child.decoratedName)
                            } else {
                                let child = self.zoneForCKRecord(childRecord)

                                if  child.isRoot && child.parentZone != nil {
                                    child.orphan()  // avoids HANG ... a root can NOT be a child, by definition
                                    child.allowSave()
                                    child.needSave()
                                }

                                let     parent = child.parentZone
                                let extraTrash = child.zoneLink == kTrashLink && parent?.isRootOfFavorites ?? false && gFavoritesManager.hasTrash

                                if  child == parent || extraTrash {
                                    child.needDestroy()
                                    // self-parenting causes infinite recursion AND extra trash favorites are annoying
                                    // destroy either on fetch
                                } else {
                                    gRecursionLogic.propagateNeeds(to: child, progenyNeeded)

                                    if  let p = parent,
                                        !p.containsCKRecord(child.record) {

                                        ///////////////////////////////////////
                                        // no child has matching record name //
                                        ///////////////////////////////////////

                                        if  let target = child.bookmarkTarget {

                                            /////////////////////////////////////////////////////
                                            // bookmark targets need writable, color and fetch //
                                            /////////////////////////////////////////////////////

                                            target.needFetch()
                                            target.maybeNeedColor()
                                            target.maybeNeedWritable()
                                        }

                                        p.addChildAndRespectOrder(child)
                                    }
                                }
                            }
                        }

                        self.columnarReport("CHILDREN (\(childrenNeeded.count)) of", self.stringForReferences(childrenNeeded, in: self.databaseID))
                        self.unorphanAll()
                        self.add(states: [.needsCount], to: childrenNeeded)
                        self.fetchChildren(onCompletion) // process remaining
                    }
                }
            }
        }
    }


    func fetchTraits(_ onCompletion: IntClosure?) {
        let    recordIDs = recordIDsWithMatchingStates([.needsTraits], pull: true)
        var    retrieved = [CKRecord] ()
        if let predicate = traitsPredicate(specificTo: recordIDs) {
            queryWith(predicate, recordType: kTraitType, properties: ZTrait.cloudProperties()) { iRecord in
                if let ckRecord = iRecord {
                    if !retrieved.contains(ckRecord) {
                        retrieved.append(ckRecord)
                    }
                } else { // nil means done
                    FOREGROUND {
                        for ckRecord in retrieved {
                            var zRecord  = self.maybeZRecordForCKRecord(ckRecord)

                            if  zRecord == nil {                                                    // if not already registered
                                zRecord  = ZTrait(record: ckRecord, databaseID: self.databaseID)    // register
                            }
                        }

                        self.columnarReport("TRAITS (\(retrieved.count))", self.stringForCKRecords(retrieved))
                        self.unorphanAll()
                        onCompletion?(0)
                    }
                }
            }
        } else {
            onCompletion?(0)
        }
    }


    func fetchBookmarks(_ onCompletion: IntClosure?) {
        let targetIDs = recordIDsWithMatchingStates([.needsBookmarks], pull: true)
        let predicate = bookmarkPredicate(specificTo: targetIDs)
        let specified = targetIDs.count != 0
        var retrieved = [CKRecord] ()

        queryWith(predicate) { iRecord in
            if  let ckRecord = iRecord {
                if !retrieved.contains(ckRecord) && ckRecord.isBookmark {
                    retrieved.append(ckRecord)
                }
            } else { // nil means done
                FOREGROUND {
                    var created = false
                    let   count = retrieved.count

                    if  count > 0 {
                        for ckRecord in retrieved {
                            var bookmark  = self.maybeZoneForCKRecord(ckRecord)
                            if  bookmark == nil {                                                   // if not already registered
                                bookmark  = Zone(record: ckRecord, databaseID: self.databaseID)     // create and register
                                created   = true
                            }

                            bookmark?.maybeNeedRoot()

                            if  let target = bookmark?.bookmarkTarget {
                                target.fetchBeforeSave()

                                if  let parent = target.parentZone {
                                    if  target.isRoot || target == parent { // no roots have a parent, by definition
                                        target.orphan()                     // avoid HANG ... unwire parent cycle
                                        target.allowSave()
                                        target.needSave()
                                    } else {
                                        parent.maybeNeedRoot()
                                        parent.needChildren()
                                        parent.fetchBeforeSave()
                                        parent.needFetch()
                                    }
                                }

                                target.maybeNeedRoot()
                                target.needChildren()
                            }
                        }

                        self.columnarReport("BOOKMARKS (\(count))", self.stringForCKRecords(retrieved))
                    }

                    if !created && !specified {
                        onCompletion?(0)                            // only async exit
                    } else {
                        self.save { iCount in                       // no-op if no zones need to be saved, in which case falls through ...
                            if      iCount == 0 {
                                self.fetchBookmarks(onCompletion)   // process remaining (or no-op)
                            }
                        }
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
            gHere = gRoot!

            onCompletion?(0)
        }

        let name  = hereRecordName ?? kRootName

        if  name == kRootName { // in case it is first time for user
            rootCompletion()
        } else if let here = maybeZRecordForRecordName(name) as? Zone {
            gHere = here

            onCompletion?(0)
        } else {
            let recordID = CKRecordID(recordName: name)

            self.assureRecordExists(withRecordID: recordID, recordType: kZoneType) { (iHereRecord: CKRecord?) in
                if  iHereRecord == nil || iHereRecord?[kpZoneName] == nil {
                    rootCompletion()
                } else {
                    let    here = self.zoneForCKRecord(iHereRecord!)
                    here.record = iHereRecord
                    gHere       = here

                    here.maybeNeedChildren()
                    here.maybeNeedRoot()
                    here.fetchBeforeSave()
                    onCompletion?(0)
                }
            }
        }
    }


    func establishRoot(_ onCompletion: IntClosure?) {
        if  rootZone != nil {
            onCompletion?(0)
        } else {
            let recordID = CKRecordID(recordName: kRootName)

            assureRecordExists(withRecordID: recordID, recordType: kZoneType) { (iRecord: CKRecord?) in
                var rootRecord  = iRecord
                if  rootRecord == nil {
                    rootRecord  = CKRecord(recordType: kZoneType, recordID: recordID)   // will create
                }

                let        root = self.zoneForCKRecord(rootRecord!)                     // get / create root
                self  .rootZone = root
                root    .parent = nil

                if  root.zoneName == nil {
                    root.zoneName  = "title"                                            // was created

                    root.needSave()
                }

                if  root.parent   != nil {
                    root.parent    = nil

                    root.needSave()
                }

                if gFullFetch {
                    root.needProgeny()
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
            let classNames = [kZoneType, kTraitType]
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

            if  oldValue        != value {
                record[property] = value as? CKRecordValue

                if  let string = value as? String, string == kNullLink {
                    // stupid freakin icloud does not store this value. ack!!!!!!
                } else if object.canSave {
                    object.needSave()
                } else {
                    object.maybeNeedMerge()
                }
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

