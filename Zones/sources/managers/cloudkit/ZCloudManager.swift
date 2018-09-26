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
    var cloudUnavailable :         Bool { return !gHasInternet || (databaseID == .mineID && !gCloudAccountIsActive) }
    var    isRemembering :         Bool = false
    var currentOperation : CKOperation? = nil
    var currentPredicate : NSPredicate? = nil


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


    func invokeOperation(for identifier: ZOperationID, cloudCallback: AnyClosure?) {
        switch identifier { // inner switch
        case .bookmarks:   fetchBookmarks  (cloudCallback)
        case .children:    fetchChildren   (cloudCallback)
        case .cloud:       fetchCloudZones (cloudCallback)
        case .emptyTrash:  emptyTrash      (cloudCallback)
        case .fetch:       fetchZones      (cloudCallback)
        case .fetchlost:   fetchLost       (cloudCallback)
        case .fetchNew:    fetchNew        (cloudCallback)
        case .fetchAll:    fetchAll        (cloudCallback)
        case .found:       found           (cloudCallback)
        case .here:        establishHere   (cloudCallback)
        case .merge:       merge           (cloudCallback)
        case .parents:     fetchParents    (cloudCallback)
        case .refetch:     refetchZones    (cloudCallback)
        case .roots:       establishRoots  (cloudCallback)
        case .save:        save            (cloudCallback)
        case .subscribe:   subscribe       (cloudCallback)
        case .traits:      fetchTraits     (cloudCallback)
        case .undelete:    undeleteAll     (cloudCallback)
        case .unsubscribe: unsubscribe     (cloudCallback)
        default: break
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
                            if  let zRecord = self.maybeZRecordForRecordID(ckRecord.recordID) {
                                zRecord.useBest(record: ckRecord)
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

            if   saves.count > 0 { columnarReport("SAVE (\(     saves.count))", String.forCKRecords(saves)) }
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

        if      cloudUnavailable {
            if  let ckRecord = maybeCKRecordForRecordName(iCKRecordID.recordName),
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
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    func queryFor(_ recordType: String, with predicate: NSPredicate, properties: [String], batchSize: Int = kBatchSize, cursor iCursor: CKQueryCursor? = nil, onCompletion: RecordErrorClosure?) {
        currentPredicate                 = predicate
        if  var                operation = configure(CKQueryOperation()) as? CKQueryOperation {
            if  let               cursor = iCursor {
                operation                = CKQueryOperation.init(cursor: cursor)
            } else {
                operation         .query = CKQuery(recordType: recordType, predicate: predicate)
            }

            operation       .desiredKeys = properties
            operation      .resultsLimit = batchSize
            operation.recordFetchedBlock = { iRecord in
                onCompletion?(iRecord, nil)
            }

            operation.queryCompletionBlock = { (iCursor, error) in
                if  let cursor = iCursor {
                    self.queryFor(recordType, with: predicate, properties: properties, cursor: cursor, onCompletion: onCompletion)  // recurse with cursor
                } else {
                    gAlertManager.alertError(error, predicate.description) { iHasError in
                        onCompletion?(nil, error)
                    }
                }
            }

            start(operation)
        } else {
            onCompletion?(nil, nil)
        }
    }


    func queryForZonesWith(_ predicate: NSPredicate, batchSize: Int = kBatchSize, onCompletion: RecordErrorClosure?) {
        queryFor(kZoneType, with: predicate, properties: Zone.cloudProperties(), batchSize: batchSize, onCompletion: onCompletion)
    }


    func predicate(since iStart: Date?, before iEnd: Date?) -> NSPredicate {
        var predicate = NSPredicate(value: true)

        if  let start = iStart {
            predicate = NSPredicate(format: "modificationDate > %@", start as NSDate)

            if  let          end = iEnd {
                let endPredicate = NSPredicate(format: "modificationDate <= %@", end as NSDate)
                predicate        = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, endPredicate])
            }
        }

        return predicate
    }


    func searchPredicateFrom(_ searchString: String) -> NSPredicate {
        let    tokens = searchString.components(separatedBy: " ")
        var    string = ""
        var separator = ""

        for token in tokens {
            if  token    != "" {
                string    = "\(string)\(separator)SELF CONTAINS \"\(token.escaped)\""
                separator = " AND "
            }
        }

        return NSPredicate(format: string)
    }


    func traitsPredicate(specificTo iRecordIDs: [CKRecordID]) -> NSPredicate? {
        if  iRecordIDs.count == 0 {
            return gIsReadyToShowUI ? nil : NSPredicate(value: true)
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


    func bookmarkPredicate(specificTo iRecordIDs: [CKRecordID]) -> NSPredicate? {
        var  predicate    = ""

        if  cloudUnavailable {
            return nil
        } else if  iRecordIDs.count == 0 {
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

        queryForZonesWith(predicate) { (iRecord, iError) in
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
                scan(self.hereZone)
                scan(gFavoritesRoot)

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


    func found(_ onCompletion: IntClosure?) {
        let states = [ZRecordState.needsFound]

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iRecordName in
            if  let zone = maybeZoneForRecordName(iRecordName) {
                clearRecordName(iRecordName, for: states)
                lostAndFoundZone?.addAndReorderChild(zone)
                lostAndFoundZone?.needSave()
                zone.needSave()
            }
        }

        onCompletion?(0)
    }


    func fetchLost(_ onCompletion: IntClosure?) {
        let    format = kpRecordName + " != \"" + kRootName + "\""
        let predicate = NSPredicate(format: format)
        var   fetched = [CKRecord] ()

        self.queryForZonesWith(predicate, batchSize: kMaxBatchSize) { (iRecord, iError) in
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
                            self.columnarReport("  FOUND (\(iCKRecords.count))", String.forCKRecords(iCKRecords))
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

                                    self.columnarReport("  FETCHED (\(iFetchedParents.count))", String.forCKRecords(iFetchedParents))
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


    func fetch(for type: String, properties: [String], since: Date?, before: Date?, _ onCompletion: RecordsClosure?) {
        let predicate = self.predicate(since: since, before: before)
        var retrieved = [CKRecord] ()

        queryFor(type, with: predicate, properties: properties, batchSize: CKQueryOperationMaximumResults) { (iRecord, iError) in
            if  iError   != nil {
                if since == nil {
                    onCompletion?(retrieved) // NEED BETTER ERROR HANDLING
                } else {
                    let middle = since?.mid(to: before)                   // if error, fetch split by two

                    self.fetch(for: type, properties: properties, since: since, before: middle) { iCKRecords in
                        retrieved.appendUnique(contentsOf: iCKRecords)

                        self.fetch(for: type, properties: properties, since: middle, before: before) { iCKRecords in
                            retrieved.appendUnique(contentsOf: iCKRecords)

                            onCompletion?(retrieved)
                        }
                    }
                }
            } else if let ckRecord = iRecord {
                retrieved.appendUnique(contentsOf: [ckRecord])
            } else { // nil means: we already received full response from cloud for this particular fetch
                onCompletion?(retrieved)
            }
        }
    }


    func createZRecords(of type: String, with iCKRecords: [CKRecord], title iTitle: String? = nil) {
        if iCKRecords.count != 0 {
            for ckRecord in iCKRecords {
                var zRecord = self.maybeZRecordForRecordName(ckRecord.recordID.recordName)

                if let link = ckRecord[kpZoneLink] as? String,
                    link == kTrashLink {
                    bam("")
                }

                if  zRecord == nil {
                    switch type {
                    case kZoneType:  zRecord =   Zone(record: ckRecord, databaseID: self.databaseID)
                    case kTraitType: zRecord = ZTrait(record: ckRecord, databaseID: self.databaseID)
                    default: break
                    }
                } else {
                    zRecord?.useBest(record: ckRecord)
                }

                zRecord?.unorphan()
            }

            self.columnarReport("FETCH\(iTitle ?? "") (\(iCKRecords.count))", String.forCKRecords(iCKRecords))
        }
    }


    func fetchAll(_ onCompletion: IntClosure?) {
        if  !gIsReadyToShowUI && recordRegistry.values.count > 10 {
            onCompletion?(0)
        } else {
            fetchSince(nil, onCompletion)
        }
    }


    func fetchNew(_ onCompletion: IntClosure?) {
        fetchSince(lastSyncDate, onCompletion)
    }


    func fetchSince(_ date: Date?, _ onCompletion: IntClosure?) {
        // for zones, traits, destroy
        // if date is nil, fetch all

        fetch(for: kZoneType, properties: Zone.cloudProperties(), since: date, before: nil) { iZoneCKRecords in
            FOREGROUND {
                self.createZRecords(of: kZoneType, with: iZoneCKRecords, title: " NEW")

                self.unorphanAll()
                self.recount()

                self.fetch(for: kTraitType, properties: ZTrait.cloudProperties(), since: date, before: nil) { iTraitCKRecords in
                    FOREGROUND {
                        self.createZRecords(of: kTraitType, with: iTraitCKRecords, title: " TRAITS")
                        onCompletion?(0)
                    }
                }
            }
        }
    }


    func fetchZones(_ onCompletion: IntClosure?) {
        let needed = recordIDsWithMatchingStates([.needsFetch, .requiresFetchBeforeSave], pull: true)

        fetchZones(needed: needed) { iCKRecords in
            FOREGROUND {
                if iCKRecords.count == 0 {
                    self.recount()
                    onCompletion?(0)
                } else {
                    self.createZRecords(of: kZoneType, with: iCKRecords)
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
                        if  let    name = iID?.recordName {
                            if  let bad = self.maybeZoneForRecordID(iID) {
                                bad.unregister()    // makes sure we do not save it to cloud

                                for orphan in bad.children {
                                    orphan.orphan()
                                    orphan.needSave()
                                    self.lostAndFoundZone?.addAndReorderChild(orphan)
                                }
                            } else {
                                self.clearRecordName(name, for: [.needsFetch])
                            }
                        }
                    } else if let ckRecord = iRecord,
                        !retrieved.contains(ckRecord) {
                        retrieved.append(ckRecord)
                        self.clearRecordName(ckRecord.recordID.recordName, for:[.requiresFetchBeforeSave, .needsFetch])
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
                    
                    self.columnarReport("PARENT (\(forReport.count)) of", String.forZones(forReport))
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

            queryForZonesWith(predicate, batchSize: kMaxBatchSize) { (iRecord, iError) in
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
                                    child.allowSaveWithoutFetch()
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

                        self.columnarReport("CHILDREN (\(childrenNeeded.count)) of", String.forReferences(childrenNeeded, in: self.databaseID))
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
            queryFor(kTraitType, with: predicate, properties: ZTrait.cloudProperties()) { (iRecord, iError) in
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

                        self.columnarReport("TRAITS (\(retrieved.count))", String.forCKRecords(retrieved))
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
        if let predicate = bookmarkPredicate(specificTo: targetIDs) {
            let specified = targetIDs.count != 0
            var retrieved = [CKRecord] ()

            queryForZonesWith(predicate) { (iRecord, iError) in
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
                                            target.allowSaveWithoutFetch()
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

                            self.columnarReport("BOOKMARKS (\(count))", String.forCKRecords(retrieved))
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
        } else {
            onCompletion?(0)
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
            self.hereZone = gRoot!

            onCompletion?(0)
        }

        let name  = hereRecordName ?? kRootName

        if  name == kRootName {

            /////////////////////////
            // first time for user //
            /////////////////////////

            rootCompletion()

        } else if let here = maybeZoneForRecordName(name) {
            hereZone = here

            onCompletion?(0)
        } else {
            let recordID = CKRecordID(recordName: name)

            self.assureRecordExists(withRecordID: recordID, recordType: kZoneType) { (iHereRecord: CKRecord?) in
                if  iHereRecord == nil || iHereRecord?[kpZoneName] == nil {
                    rootCompletion()
                } else {
                    let      here = self.zoneForCKRecord(iHereRecord!)
                    here  .record = iHereRecord
                    self.hereZone = here

                    here.maybeNeedChildren()
                    here.maybeNeedRoot()
                    here.fetchBeforeSave()
                    onCompletion?(0)
                }
            }
        }
    }


    func establishRoots(_ onCompletion: IntClosure?) {
        let         rootIDs: [ZRootID]   = [.favorites, .destroy, .trash, .graph, .lost]
        var establishRootAt: IntClosure? = nil // pre-declare so can recursively call from within
        establishRootAt                  = { iIndex in
            if iIndex >= rootIDs.count {
                onCompletion?(0)
            } else {
                let            rootID = rootIDs[iIndex]
                let        recordName = rootID.rawValue
                var              name = self.databaseID.text + " " + recordName
                let establishNextRoot = { establishRootAt?(iIndex + 1) }

                switch rootID {
                case .favorites: if self.favoritesZone    != nil || self.databaseID != .mineID { establishNextRoot(); return } else { name = kFavoritesName }
                case .graph:     if self.rootZone         != nil                               { establishNextRoot(); return } else { name = kFirstIdeaTitle }
                case .lost:      if self.lostAndFoundZone != nil                               { establishNextRoot(); return }
                case .trash:     if self.trashZone        != nil                               { establishNextRoot(); return }
                case .destroy:   if self.destroyZone      != nil                               { establishNextRoot(); return }
                }

                self.establishRootFor(name: name, recordName: recordName) { iZone in
                    if  rootID != .graph {
                        iZone.directAccess = .eDefaultName
                    }

                    switch rootID {
                    case .favorites: self.favoritesZone    = iZone
                    case .destroy:   self.destroyZone      = iZone
                    case .trash:     self.trashZone        = iZone
                    case .graph:     self.rootZone         = iZone
                    case .lost:      self.lostAndFoundZone = iZone
                    }

                    establishNextRoot()
                }
            }
        }

        establishRootAt?(0)
    }


    func establishRootFor(name: String, recordName: String, _ onCompletion: ZoneClosure?) {
        let recordID = CKRecordID(recordName: recordName)

        assureRecordExists(withRecordID: recordID, recordType: kZoneType) { (iRecord: CKRecord?) in
            var record  = iRecord
            if  record == nil {
                record  = CKRecord(recordType: kZoneType, recordID: recordID)       // will create
            }

            let           zone = self.zoneForCKRecord(record!)                      // get / create
            zone       .parent = nil

            if  zone.zoneName == nil {
                zone.zoneName  = name                                               // was created

                zone.needSave()
            }

            if  zone.parent   != nil {
                zone.parent    = nil

                zone.needSave()
            }

            onCompletion?(zone)
        }
    }


    // MARK:- remote persistence
    // MARK:-


    func unsubscribe(_ onCompletion: IntClosure?) {
        if  cloudUnavailable {
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
        if  cloudUnavailable {
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
                } else if object.canSaveWithoutFetch {
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

