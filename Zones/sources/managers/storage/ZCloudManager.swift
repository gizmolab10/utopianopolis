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
    var         database :  CKDatabase? { return gRemoteStoresManager.databaseForMode(storageMode) }
    var   refetchingName :       String { return "remember.\(storageMode.rawValue)" }
    var        _manifest :   ZManifest? = nil
    var currentOperation : CKOperation? = nil
    var currentPredicate : NSPredicate? = nil
    var    isRemembering :         Bool = false



    var manifest : ZManifest {
        if  _manifest == nil {
            _manifest = gRemoteStoresManager.manifest(for: storageMode)
        }

        return _manifest!
    }


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
        let   saves = pullCKRecordsWithMatchingStates([.needsSave])  // clears state BEFORE looking at manifest
        let destroy = pullRecordIDsWithHighestLevel(for: [.needsDestroy], batchSize: 20)
        let   count = saves.count + destroy.count

        if  count > 0, let           operation = configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
            operation              .savePolicy = .allKeys
            operation           .recordsToSave = saves
            operation       .recordIDsToDelete = destroy
            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iError: Error?) in
                gAlertManager.detectError(iError) { iHasError in
                    if  iHasError {
                        let notDestroy = iRecord == nil || !destroy.contains(iRecord!.recordID)

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
                            if  let zone = self.maybeZoneForRecordID(recordID) {
                                self.unregisterZRecord(zone)
                            }
                        }
                    }

                    if  let saved = iSavedCKRecords {
                        for ckrecord: CKRecord in saved {
                            if  let zone = self.maybeZoneForRecordID(ckrecord.recordID) {
                                zone.record = ckrecord
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
            if destroy.count > 0 { columnarReport("DESTROY \(destroy.count)", stringForRecordIDs(destroy)) }

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
//                self.columnarReport("DELETE", String(describing: iRecord![kZoneName]))
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
//                let            root = gRemoteStoresManager.rootZone(for: self.storageMode)
//                let         deleted = self.maybeZRecordForCKRecord(iRecord) as? Zone ?? Zone(record: iRecord, storageMode: self.storageMode)
//
//                if  deleted.parent != nil {
//                    deleted.needParent()
//                } else {
//                    deleted.parentZone = root
//
//                    root?.maybeNeedFetch()
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


    func traitsPredicate(specificTo iRecordIDs: [CKRecordID]) -> NSPredicate {
        if  iRecordIDs.count == 0 {
            return NSPredicate(value: true)
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
                        gAlertManager.alertError("MERGE within \(self.storageMode) \(iError!)")

                        if let id = iID, let index = recordIDs.index(of: id) {
                            recordIDs.remove(at: index)
                        }
                    } else if let record = iRecord {
                        recordsByID[record] = iID
                    }
                }

                self.clearRecordID(iID, for:[.needsMerge])
            }

            operation.completionBlock = {
                FOREGROUND {
                    if  recordsByID.count == 0 {
                        for ckRecordID in recordIDs {
                            self.clearRecordID(ckRecordID, for: [.needsMerge])
                        }
                    } else {
                        for (iRecord, iID) in recordsByID {
                            if  let zRecord = self.maybeZRecordForRecordID(iID) {
                                zRecord.mergeIntoAndTake(iRecord)
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
        if !isRemembering {
            isRemembering = true
        } else {
            onCompletion?(0)

            return
        }

        BACKGROUND {     // not stall foreground processor
            var memorables = [String] ()

            let scan: ObjectClosure = { iObject in
                if let zone = iObject as? Zone {
                    zone.traverseAllProgeny { iZone in
                        if !iZone.isAutoGenerated,
                            iZone.alreadyExists,
                            iZone.storageMode == self.storageMode,
                            let identifier = iZone.recordName,
                            !memorables.contains(identifier) {
                            memorables.append(identifier)
                        }
                    }
                }
            }

            scan(self.rootZone)
            scan(self.manifest.hereZone)
            scan(gFavoritesManager.rootZone)

            self.columnarReport("REMEMBER \(memorables.count)", "\(self.storageMode.rawValue)")
            setString(memorables.joined(separator: kSeparator), for: self.refetchingName)

            self.isRemembering = false

            onCompletion?(0)
        }
    }


    func refetch(_ onCompletion: IntClosure?) {
        if  let fetchables = getString(for: refetchingName, defaultString: "")?.components(separatedBy: kSeparator) {
            let   fetching = [ZRecordState.needsFetch]

            for fetchable in fetchables {
                if fetchable != "" {
                    addCKRecord(CKRecord(for: fetchable), for: fetching)
                }
            }

            fetch(onCompletion)
        }
    }


    func fetchLost(_ onCompletion: IntClosure?) {
        let predicate = NSPredicate(format: kZoneName + " != \"\(kRootName)\"")
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

                            if  !parentID.isAutoGenerated,
                                self.notRegistered(parentID) {
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
                            self.columnarReport("  LOSING (\(iCKRecords.count))", self.stringForCKRecords(iCKRecords))
                            for ckRecord in iCKRecords {
                                lost.addZone(for: ckRecord)

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

                                self.fetch(needed: seekParentIDs) { iFetchedParents in
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


    func fetch(_ onCompletion: IntClosure?) {
        let needed = recordIDsWithMatchingStates([.needsFetch], pull: true)

        fetch(needed: needed) { iCKRecords in
            FOREGROUND {
                if iCKRecords.count == 0 {
                    onCompletion?(0)
                } else {
                    for ckRecord in iCKRecords {
                        var zRecord  = self.maybeZRecordForCKRecord(ckRecord)

                        if  zRecord == nil {
                            zRecord  = ZRecord(record: ckRecord, storageMode: self.storageMode)
                        } else {
                            zRecord?.record = ckRecord
                        }
                    }

                    self.columnarReport("FETCH \(iCKRecords.count)", self.stringForCKRecords(iCKRecords))
                    self.fetch(onCompletion)                            // process remaining
                }
            }
        }
    }


    func fetch(needed: [CKRecordID], _ onCompletion: RecordsClosure?) {
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
                            self.clearRecordID(iID, for: [.needsFetch])
                        }
                    } else if let ckRecord = iRecord,
                        !retrieved.contains(ckRecord) {
                        retrieved.append(ckRecord)
                        self.clearRecordID(ckRecord.recordID, for:[.doNotSave, .needsFetch])
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
        if  manifest.alreadyExists || manifest.needsMerge || manifest.needsSave {
            onCompletion?(0)
        } else {
            let recordID = manifest.record.recordID
            let     mine = gRemoteStoresManager.cloudManagerFor(.mineMode)

            mine.assureRecordExists(withRecordID: recordID, recordType: kManifestType) { (iManifestRecord: CKRecord?) in
                if  iManifestRecord     != nil {
                    self.manifest.record = iManifestRecord

                    if  let hereRecordName = self.manifest.here,
                        let           mode = self.manifest.manifestMode {
                        let         hereID = CKRecordID(recordName: hereRecordName)
                        let   cloudManager = gRemoteStoresManager.cloudManagerFor(mode)

                        cloudManager.assureRecordExists(withRecordID: hereID, recordType: kZoneType) { iCKRecord in
                            if  let hereRecord = iCKRecord {
                                self.manifest._hereZone = cloudManager.zoneForCKRecord(hereRecord)
                            }

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
        let         missingParentIDs = parentIDsWithMatchingStates(states)
        let                orphans = recordIDsWithMatchingStates(states)
        let                  count = missingParentIDs.count

        if  count > 0, let operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            var        recordsByID = [CKRecord : CKRecordID?] ()
            operation   .recordIDs = missingParentIDs

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

                    for (parentRecord, parentID) in recordsByID {
                        var fetchedParent  = self.maybeZoneForRecordID(parentID)

                        if  fetchedParent != nil {
                            fetchedParent?.mergeIntoAndTake(parentRecord) // BROKEN: likely this does not do what's needed here .... yikes! HUH?
                        } else {
                            fetchedParent  = self.zoneForCKRecord(parentRecord) // BAD DUMMY ?
                        }

                        if  let         p = fetchedParent {
                            let fetchedID = p.record.recordID

                            for orphan in orphans {
                                if  let  child = self.maybeZoneForRecordID(orphan), let parentID = child.parentZone?.record.recordID, parentID == fetchedID {
                                    let states = self.states(for: child.record)

                                    if  child.isRoot || child == p {
                                        child.parentZone = nil

                                        child.maybeNeedSave()
                                    } else if !p.children.contains(child) {
                                        p.children.append(child)
                                    }

                                    if !forReport.contains(child) {
                                        forReport.append(child)
                                    }

                                    if  states.contains(.needsRoot) {
                                        p.maybeNeedRoot()
                                        p.needChildren()
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


    func fetchChildren(_ onCompletion: IntClosure?) {
        let  progenyNeeded = pullReferencesWithMatchingStates([.needsProgeny])
        let childrenNeeded = pullReferencesWithMatchingStates([.needsChildren]) + progenyNeeded
        let   destroyedIDs = recordIDsWithMatchingStates([.needsDestroy])
        let          count = childrenNeeded.count

        onCompletion?(count)

        if count > 0 {
            var  retrieved = [CKRecord] ()
            let  predicate = NSPredicate(format: "parent IN %@", childrenNeeded)

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
                                let      child = self.zoneForCKRecord(childRecord) // BAD DUMMY ?
                                let     parent = child.parentZone
                                let extraTrash = child.zoneLink == kTrashLink && parent?.isRootOfFavorites ?? false && gFavoritesManager.hasTrash

                                if  child.isRoot {
                                    child.parent = nil  // avoids HANG ... a root can NOT be a child, by definition
                                } else if child == parent || extraTrash {
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

                                            ///////////////////////////////////////////////////////////
                                            // bookmark targets need writable, color and maybe fetch //
                                            ///////////////////////////////////////////////////////////

                                            target.maybeNeedFetch()
                                            target.maybeNeedColor()
                                            target.maybeNeedWritable()
                                        }

                                        p.add(child)
                                        p.respectOrder()
                                    }
                                }
                            }
                        }

                        self.columnarReport("CHILDREN of", self.stringForReferences(childrenNeeded, in: self.storageMode))
                        self.add(states: [.needsCount], to: childrenNeeded)
                        self.fetchChildren(onCompletion) // process remaining
                    }
                }
            }
        }
    }


    func fetchTraits(_ onCompletion: IntClosure?) {
        let recordIDs = recordIDsWithMatchingStates([.needsTraits], pull: true)
        let predicate = traitsPredicate(specificTo: recordIDs)
        var retrieved = [CKRecord] ()

        queryWith(predicate, recordType: kTraitType, properties: ZTrait.cloudProperties()) { iRecord in
            if let ckRecord = iRecord {
                if !retrieved.contains(ckRecord) {
                    retrieved.append(ckRecord)
                }
            } else { // nil means done
                FOREGROUND {
                    for ckRecord in retrieved {
                        var zRecord  = self.maybeZRecordForCKRecord(ckRecord)

                        if  zRecord == nil {                                                   // if not already registered
                            zRecord  = ZTrait(record: ckRecord, storageMode: self.storageMode) // register
                        }
                    }

                    onCompletion?(0)
                }
            }
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
                            var zone    = self.maybeZoneForCKRecord(ckRecord)
                            if  zone   == nil {                                                 // if not already registered
                                zone    = Zone(record: ckRecord, storageMode: self.storageMode) // create and register
                                created = true

                                zone?.maybeNeedFetch()
                                zone?.needParent()
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
            self.manifest.hereZone = gRoot!

            onCompletion?(0)
        }

        if manifest.here == nil { // first time user
            rootCompletion()
        } else {
            let recordID = CKRecordID(recordName: manifest.here!)

            self.assureRecordExists(withRecordID: recordID, recordType: kZoneType) { (iHereRecord: CKRecord?) in
                if  iHereRecord == nil || iHereRecord?[kZoneName] == nil {
                    rootCompletion()
                } else {
                    let               here = self.zoneForCKRecord(iHereRecord!)
                    here           .record = iHereRecord
                    self.manifest.hereZone = here

                    here.maybeNeedRoot()
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
                    rootRecord  = CKRecord(recordType: kZoneName, recordID: recordID)
                }

                self.rootZone = self.zoneForCKRecord(rootRecord!)    // get / create root7

                if  self.rootZone?.zoneName == nil {
                    self.rootZone?.zoneName = "title"
                }

                self.rootZone?.maybeNeedSave()
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
            let classNames = [kZoneType, kManifestType]
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

