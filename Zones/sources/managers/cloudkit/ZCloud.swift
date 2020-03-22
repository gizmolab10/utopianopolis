//
//  ZCloud.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 9/18/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


let gContainer = CKContainer(identifier: kCloudID)


class ZCloud: ZRecords {
    var   cloudZonesByID = [CKRecordZone.ID : CKRecordZone] ()
    var         database :  CKDatabase? { return gRemoteStorage.databaseForID(databaseID) }
    var   refetchingName :       String { return "remember.\(databaseID.rawValue)" }
    var cloudUnavailable :         Bool { return !gHasInternet || (databaseID == .mineID && !gCanAccessMyCloudDatabase) }
    var    isRemembering :         Bool = false
    var currentOperation : CKOperation?
    var currentPredicate : NSPredicate?
	var recordsToProcess = [CKRecord]()

    func configure(_ operation: CKDatabaseOperation) -> CKDatabaseOperation? {
        if  database != nil {
			let                        configuration = operation.configuration ?? CKOperation.Configuration()
			configuration.timeoutIntervalForResource = kRemoteTimeout
            configuration.timeoutIntervalForRequest  = kRemoteTimeout
            configuration                 .container = gContainer
			operation                 .configuration = configuration
			operation              .qualityOfService = .background

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
        case .oBookmarks:     fetchBookmarks    (cloudCallback)
        case .oChildren:      fetchChildren     (cloudCallback)
        case .oCloud:         fetchCloudZones   (cloudCallback)
        case .oEmptyTrash:    emptyTrash        (cloudCallback)
        case .oFetchNeeded:   fetchNeeded       (cloudCallback)
        case .oFetchLost:     fetchLost         (cloudCallback)
        case .oFetchNew:      fetchNew          (cloudCallback)
        case .oFetchAll:      fetchAll          (cloudCallback)
        case .oFound:         found             (cloudCallback)
        case .oHere:          establishHere     (cloudCallback)
        case .oFetchAndMerge: fetchAndMerge     (cloudCallback)
        case .oParents:       fetchParents      (cloudCallback)
        case .oRefetch:       refetchZones      (cloudCallback)
        case .oRoots:         establishRoots    (cloudCallback)
        case .oManifest:      establishManifest (cloudCallback)
        case .oSaveToCloud:   save              (cloudCallback)
        case .oSubscribe:     subscribe         (cloudCallback)
		case .oAllTraits:     fetchAllTraits    (cloudCallback)
		case .oTraits:        fetchTraits       (cloudCallback)
        case .oUndelete:      undeleteAll       (cloudCallback)
        case .oRecount:       recount           (cloudCallback)
        default:                                 cloudCallback?(0) // empty operations (e.g., .oStartUp and .oFinishUp)
        }
    }


    // MARK:- push to cloud
    // MARK:-


    func save(_ onCompletion: IntClosure?) {
        let   saves = pullCKRecordsWithMatchingStates([.needsSave])
        let destroy = pullRecordIDsWithHighestLevel(for: [.needsDestroy], batchSize: 20)
        let   count = saves.count + destroy.count

        if  count > 0, let           operation = configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
            operation              .savePolicy = .changedKeys
            operation           .recordsToSave = saves
            operation       .recordIDsToDelete = destroy
            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iError: Error?) in
                let                 notDestroy = iRecord == nil || !destroy.contains(iRecord!.recordID)
                gAlerts.detectError(iError) { iHasError in
                    if  iHasError {
                        if  notDestroy,
                            let     ck = iError as? CKError,
                            ck.code   == .serverRecordChanged, // oplock error
                            let record = self.maybeZRecordForCKRecord(iRecord) {
                            record.maybeNeedMerge()
                        } else {
                            let message = iRecord?.description ?? ""
                            printDebug(.error, String(describing: iError!) + "\n" + message)
                        }
                    }
                }
            }

            operation.modifyRecordsCompletionBlock = { (iSavedCKRecords, iDeletedRecordIDs, iError) in
                // deal with saved records marked as deleted

                FOREGROUND {
                    if  let destroyed = iDeletedRecordIDs {
                        if  destroyed.count > 0 { self.columnarReport("DESTROY (\(destroyed.count))", self.stringForRecordIDs(destroyed)) }
                        for recordID: CKRecord.ID in destroyed {
                            if  let zRecord = self.maybeZRecordForRecordID(recordID) { // zones AND traits
                                zRecord.orphan()
                                self.unregisterZRecord(zRecord)
                            }
                        }
                    }

                    if  let saved = iSavedCKRecords {
                        if  saved.count > 0 { self.columnarReport("SAVE (\(     saved.count))", String.forCKRecords(saved)) }

                        for ckRecord: CKRecord in saved {
                            if  let zRecord = self.maybeZRecordForRecordID(ckRecord.recordID) {
                                zRecord.useBest(record: ckRecord)
                                ckRecord.maybeMarkAsFetched(self.databaseID)
                                zRecord.removeState(.needsSave)
                            }
                        }
                    }

                    gAlerts.detectError(iError, "") { iHasError in
                        if iHasError {
                            printDebug(.error, String(describing: iError!))
                        }
                    }

                    self.fetchAndMerge { iCount in              // process merges caused (before now) by save oplock errors
                        if iCount == 0 {
                            self.save(onCompletion)         // process any remaining
                        }
                    }
                }
            }

			onCompletion?(1)
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
//                let            root = gRemoteStorage(for: self.databaseID)
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

    
    func assureRecordExists(withRecordID iCKRecordID: CKRecord.ID?, recordType: String?, onCompletion: @escaping RecordClosure) {
        detectIfRecordExists(withRecordID: iCKRecordID, recordType: recordType, mustCreate: true, onCompletion: onCompletion)
    }
    

    func detectIfRecordExists(withRecordID iCKRecordID: CKRecord.ID?, recordType: String?, mustCreate: Bool = false, onCompletion: @escaping RecordClosure) {
        let done:  RecordClosure = { (iCKRecord: CKRecord?) in
            FOREGROUND(canBeDirect: true) {
                iCKRecord?.maybeMarkAsFetched(self.databaseID)
                onCompletion(iCKRecord)
            }
        }

        guard let ckRecordID = iCKRecordID else {
            done(nil)
            
            return
        }

        if  let ckRecord = maybeCKRecordForRecordName(ckRecordID.recordName),
            hasCKRecordName(ckRecordID.recordName, forAnyOf: [.notFetched]) {
            done(ckRecord)
        } else if cloudUnavailable {
            done(nil)
        } else {
            let p = properties(for: recordType)

            reliableFetch(needed: [ckRecordID], properties: p) { iCKRecords in
                if iCKRecords.count != 0 {
                    done(iCKRecords[0])
                } else if !mustCreate {
                    done(nil)
                } else if let type = recordType {
                    done(CKRecord(recordType: type, recordID: ckRecordID))
                } else {
                    done(nil)
                }
            }
        }
    }
    
    
    func fetchRecord(for recordID: CKRecord.ID) {
        
        // //////////////////////////////////////
		// BUG: could be a trait or a deletion //
        // //////////////////////////////////////
		
        detectIfRecordExists(withRecordID: recordID, recordType: kZoneType) { iUpdatedRecord in
            if  let ckRecord = iUpdatedRecord, !ckRecord.isEmpty {
                let     zone = self.zone(for: ckRecord)
                if ckRecord == zone.record {    // record data is new (zone for just updated it)
                    zone.addToParent() { iZone in
                        gControllers.signalFor(iZone, regarding: .eRelayout)
                    }
                }
            }
        }
    }


    func queryFor(_ recordType: String, with predicate: NSPredicate, properties: [String], batchSize: Int = kBatchSize, cursor iCursor: CKQueryOperation.Cursor? = nil, onCompletion: RecordErrorClosure?) {
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
                    gAlerts.alertError(error, predicate.description) { iHasError in
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

	func queryForTraitsWith(_ predicate: NSPredicate, batchSize: Int = kBatchSize, onCompletion: RecordErrorClosure?) {
		queryFor(kTraitType, with: predicate, properties: ZTrait.cloudProperties(), batchSize: batchSize, onCompletion: onCompletion)
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

    func zoneSearchPredicateFrom(_ searchString: String) -> NSPredicate? {
        let    tokens = searchString.components(separatedBy: " ")
        var    string = ""
        var separator = ""

        for token in tokens {
            if  token    != "" {
                string    = "\(string)\(separator)SELF CONTAINS \"\(token.escaped)\""
                separator = " AND "
            }
        }

        return string == "" ? nil : NSPredicate(format: string)
    }

	func noteSearchPredicateFrom(_ searchString: String) -> NSPredicate? {
		let    tokens = searchString.components(separatedBy: " ")
		var    string = ""
		var separator = ""

		for token in tokens {
			if  token    != "" {
				string    = String(format: "%@%@SELF.strings CONTAINS \"%@\"", string, separator, token)
				separator = " AND "
			}
		}

		return string == "" ? nil : NSPredicate(format: string)
	}

    func traitsPredicate(specificTo iRecordIDs: [CKRecord.ID]) -> NSPredicate? {
        if  iRecordIDs.count == 0 {
            return !gIsReadyToShowUI ? nil : NSPredicate(value: true)
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


    func bookmarkPredicate(specificTo iRecordIDs: [CKRecord.ID]) -> NSPredicate? {
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
		var retrieved = [CKRecord] ()

		guard let zonesPredicate = zoneSearchPredicateFrom(searchString),
			let   notesPredicate = noteSearchPredicateFrom(searchString) else {
			onCompletion?(retrieved as NSObject)

			return
		}

        queryForZonesWith(zonesPredicate) { (iRecord, iError) in
            if  let ckRecord = iRecord {
                if !retrieved.contains(ckRecord) {
                    retrieved.append(ckRecord)
                }
            } else {
				self.queryForTraitsWith(notesPredicate) { (iRecord, iError) in
					if  let ckRecord = iRecord {
						if !retrieved.contains(ckRecord) {
							retrieved.append(ckRecord)
						}
					} else {
						onCompletion?(retrieved as NSObject)
					}
				}
            }
        }
    }


    func fetchAndMerge(_ onCompletion: IntClosure?) {
        var recordIDs = recordIDsWithMatchingStates([.needsMerge])
        let     count = recordIDs.count

        if  count > 0, let           operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            var                   receivedByID = [CKRecord : CKRecord.ID?] ()
            operation               .recordIDs = recordIDs
            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecord.ID?, iError: Error?) in
                gAlerts.detectError(iError) { iHasError in
                    if  iHasError {
                        let    zone = self.maybeZoneForRecordID(iID)
                        let message = zone == nil ? String(describing: iError) : zone?.unwrappedName

                        gAlerts.alertError("MERGE within \(self.databaseID) \(message!)")

                        if let id = iID, let index = recordIDs.firstIndex(of: id) {
                            recordIDs.remove(at: index)
                        }
                    } else if let record = iRecord {
                        receivedByID[record] = iID
                    }
                }

                self.clearRecordName(iID?.recordName, for:[.needsMerge])
            }

            operation.completionBlock = {
                FOREGROUND {
                    if  receivedByID.count == 0 {
                        for ckRecordID in recordIDs {
                            self.clearRecordName(ckRecordID.recordName, for: [.needsMerge]) // mark as merged
                        }
                    } else {
                        for (iReceivedRecord, iID) in receivedByID {
                            if  let zRecord = self.maybeZRecordForRecordID(iID) {
                                zRecord.useBest(record: iReceivedRecord)
                            }
                        }
                    }

					///////////////////////
					//      RECURSE      //
					///////////////////////

					self.fetchAndMerge(onCompletion)    // process remaining
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
                setPreferencesString(memorables.joined(separator: kNameSeparator), for: self.refetchingName)

                self.isRemembering = false

                onCompletion?(0)
            }
        }
    }


    func refetchZones(_ onCompletion: IntClosure?) {
        if  let fetchables = getPreferencesString(for: refetchingName, defaultString: "")?.components(separatedBy: kNameSeparator) {
            for fetchable in fetchables {
                if fetchable != "" {
                    addCKRecord(CKRecord(for: fetchable), for: [.needsFetch])
                }
            }

            fetchNeeded(onCompletion) // includes processing logic for retrieved records
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
                    var               lost = self.createRandomLost()
                    var          parentIDs = [CKRecord.ID] ()
                    var             toLose = [CKRecord] ()
                    var childrenRecordsFor = [CKRecord.ID : [CKRecord]] ()
                    let         isOrphaned = { (iCKRecord: CKRecord) -> Bool in
                        if  let  parentRef = iCKRecord[parentKey] as? CKRecord.Reference {
                            let  parentID  = parentRef.recordID

                            if  self.notRegistered(parentID) {
                                parentIDs.append(parentID)

                                if  childrenRecordsFor[parentID] == nil {
                                    childrenRecordsFor[parentID]  = []
                                }

                                childrenRecordsFor[parentID]?.append(iCKRecord)
                            }

                            return false
                        } else if let parentLink = iCKRecord[kpZoneParentLink] as? String, self.recordName(from: parentLink) != nil {
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
                        var missingIDs = [CKRecord.ID] ()
                        var fetchClosure : Closure?
                        
                        fetchClosure = {
                            if  parentIDs.count == 0 {
                                onCompletion?(0)
                            } else {
                                var seekParentIDs = parentIDs

                                for recordID in missingIDs {
                                    if  let index = seekParentIDs.firstIndex(of: recordID) {
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
                                        if  let index = seekParentIDs.firstIndex(of: ckParent.recordID) {
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


    func fetch(for type: String, properties: [String], since start: Date?, before end: Date? = nil, _ onCompletion: RecordsClosure?) {
        let predicate = self.predicate(since: start, before: end)
        var retrieved = [CKRecord] ()

        queryFor(type, with: predicate, properties: properties, batchSize: kBatchSize) { (iRecord, iError) in
            if  iError   != nil {
                if start == nil {
                    onCompletion?(retrieved) // NEED BETTER ERROR HANDLING
				} else if let middle = start?.mid(to: end) {                  // if error, fetch split by two
                    self.fetch(for: type, properties: properties, since: start, before: middle) { iCKRecords in
                        retrieved.appendUnique(contentsOf: iCKRecords)

                        self.fetch(for: type, properties: properties, since: middle, before: end) { iCKRecords in
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
        if  iCKRecords.count != 0,
			let timerID = ZTimerID.recordsID(for: databaseID) {
			recordsToProcess.appendUnique(contentsOf: iCKRecords)
			gTimers.assureCompletion(for: timerID, now: true, withTimeInterval: 1.0) {
				repeat {
					if  let ckRecord = self.recordsToProcess.dropFirst().first {
						var  zRecord = self.maybeZRecordForRecordName(ckRecord.recordID.recordName)

						if  zRecord != nil {
							zRecord?.useBest(record: ckRecord) // fetched has same record id
						} else {
							switch type {
								case kZoneType:  zRecord =   Zone(record: ckRecord, databaseID: self.databaseID)
								case kTraitType: zRecord = ZTrait(record: ckRecord, databaseID: self.databaseID)
								default: break
							}
						}

						zRecord?.unorphan()
						try gTestForUserInterrupt()					}
				} while self.recordsToProcess.count > 0
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

        fetch(for: kZoneType, properties: Zone.cloudProperties(), since: date) { iZoneCKRecords in
            FOREGROUND {
                self.fetch(for: kTraitType, properties: ZTrait.cloudProperties(), since: date) { iTraitCKRecords in
                    FOREGROUND {
                        self.createZRecords(of: kTraitType, with: iTraitCKRecords, title: " TRAITS")
                        onCompletion?(0)
                    }
                }

				self.createZRecords(of: kZoneType, with: iZoneCKRecords, title: date != nil ? " NEW" : " ALL")
				self.unorphanAll()
				self.recount()
            }
        }
    }


    func fetchNeeded(_ onCompletion: IntClosure?) {
        let needed = recordIDsWithMatchingStates([.needsFetch, .requiresFetchBeforeSave], pull: true)

        fetchZones(needed: needed) { iCKRecords in
            FOREGROUND {
                if iCKRecords.count == 0 {
                    self.recount()
                    onCompletion?(0)
                } else {
                    self.createZRecords(of: kZoneType, with: iCKRecords)
                    self.unorphanAll()
                    self.fetchNeeded(onCompletion)                            // process remaining
                }
            }
        }
    }


    func fetchZones(needed:   [CKRecord.ID], _ onCompletion: RecordsClosure?) {
        var   IDsToFetchNow = [CKRecord.ID] ()
        var       retrieved = [CKRecord] ()
        var IDsToFetchLater = needed
        var fetchClosure : Closure?

        fetchClosure = {
            let count = IDsToFetchLater.count
            IDsToFetchNow = IDsToFetchLater

            if  count == 0 {

				//////////
				// DONE //
				//////////
				
                onCompletion?(retrieved)
            } else {
                if  count <= kBatchSize {
                    IDsToFetchLater = []
                } else {
					// remove -> remainder ... ids that don't fit batch size
                    IDsToFetchNow.removeSubrange(kBatchSize ..< count)
                    IDsToFetchLater.removeSubrange(0 ..< kBatchSize)
                }

                self.reliableFetch(needed: IDsToFetchNow) { iCKRecords in
                    retrieved.append(contentsOf: iCKRecords)

					/////////////
					// RECURSE //
					/////////////

					fetchClosure?()
                }
            }
        }

        fetchClosure?()
    }


    func reliableFetch(needed: [CKRecord.ID], properties: [String] = Zone.cloudProperties(), _ onCompletion: RecordsClosure?) {
        let count = needed.count

        if  count > 0, let operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            var            retrieved = [CKRecord] ()
            operation   .desiredKeys = properties
            operation     .recordIDs = needed

            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecord.ID?, iError: Error?) in
                gAlerts.alertError(iError) { iHasError in
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
                        !retrieved.contains(ckRecord),
                        !ckRecord.isDeleted(dbID: self.databaseID) {
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
            var         fetchedRecordsByID = [CKRecord : CKRecord.ID?] ()
            operation           .recordIDs = missingParentIDs

            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecord.ID?, iError: Error?) in
                gAlerts.alertError(iError) { iHasError in
                    if  !iHasError, iRecord != nil {
                        fetchedRecordsByID[iRecord!] = iID
                    }
                }
            }

            operation.completionBlock = {
                FOREGROUND {
                    var forReport  = ZoneArray ()

                    for (fetchedRecord, fetchedID) in fetchedRecordsByID {
                        var maybe  = self.maybeZoneForRecordID(fetchedID)
                        if  maybe != nil {
                            maybe?.useBest(record: fetchedRecord)
                        } else {
                            maybe  = self.zone(for: fetchedRecord)
                        }

                        if  let    fetched = maybe,     // always not nil
                            let recordName = fetched.recordName {

                            fetched.maybeNeedChildren()

                            for childID in childrenIDs {
                                if  let   child = self.maybeZoneForRecordID(childID), !fetched.spawnedBy(child),
                                    recordName == child.parentZone?.recordName,
                                    let       r = child.record {
                                    let  states = self.states(for: r)

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
            var  progenyNeeded = [CKRecord.Reference] ()
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

                        // /////////////////////////
                        // now we can mutate heap //
                        // /////////////////////////

                        for childRecord in retrieved {
                            let     identifier = childRecord.recordID

                            if destroyedIDs.contains(identifier) {
                                // self.columnarReport(" DESTROYED", child.decoratedName)
                            } else {
                                let child = self.zone(for: childRecord)

                                if  child.isRoot && child.parentZone != nil {
                                    child.orphan()  // avoids HANG ... a root can NOT be a child, by definition
                                    child.allowSaveWithoutFetch()
                                    child.needSave()
                                }

                                let     parent = child.parentZone
                                let extraTrash = child.zoneLink == kTrashLink && parent?.isRootOfFavorites ?? false && gFavorites.hasTrash

                                if  child == parent || extraTrash {
                                    child.needDestroy()
                                    // self-parenting causes infinite recursion AND extra trash favorites are annoying
                                    // destroy either on fetch
                                } else {
                                    gRecursionLogic.propagateNeeds(to: child, progenyNeeded)

                                    if  let p = parent,
                                        !p.containsCKRecord(child.record) {

                                        // ////////////////////////////////////
                                        // no child has matching record name //
                                        // ////////////////////////////////////

                                        if  let target = child.bookmarkTarget {

                                            // //////////////////////////////////////////////////
                                            // bookmark targets need writable, color and fetch //
                                            // //////////////////////////////////////////////////

                                            target.needFetch()
                                            target.maybeNeedColor()
                                            target.maybeNeedWritable()
                                        }

                                        p.addChildAndRespectOrder(child)
                                    }
                                }
                            }
                        }

                        self.columnarReport("CHILDREN (\(childrenNeeded.count))", String.forReferences(childrenNeeded, in: self.databaseID))
                        self.unorphanAll()
                        self.add(states: [.needsCount], to: childrenNeeded)
                        self.fetchChildren(onCompletion) // process remaining
                    }
                }
            }
        }
    }

    
    func establishManifest(_ onCompletion: IntClosure?) {
        var retrieved = [CKRecord] ()
        let predicate = NSPredicate(value: true)

        queryFor(kManifestType, with: predicate, properties: ZManifest.cloudProperties()) { (iRecord, iError) in
            if let ckRecord = iRecord {
                if !retrieved.contains(ckRecord) {
                    retrieved.append(ckRecord)
                }
            } else { // nil means done
                FOREGROUND {
                    for ckRecord in retrieved {
                        if  self.manifest == nil {
                            self.manifest  = ZManifest(record: ckRecord, databaseID: self.databaseID)
                        } else {
                            self.manifest?.useBest(record: ckRecord)
                        }
                        
                        self.manifest?.apply()
                    }
                    
                    self.columnarReport("    \(self.manifest?.deleted?.count ?? 0)", "\(self.databaseID.rawValue)")
                    onCompletion?(0)
                }
            }
        }
	}

	func fetchAllTraits(_ onCompletion: IntClosure?) {
		fetchTraits(with: [], onCompletion)
	}

	func fetchTraits(_ onCompletion: IntClosure?) {
		fetchTraits(with: recordIDsWithMatchingStates([.needsTraits], pull: true), onCompletion)
    }

	func fetchTraits(with recordIDs: [CKRecord.ID], _ onCompletion: IntClosure?) {
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

                gRemoteStorage.resetBadgeCounter()

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
            self.hereZoneMaybe = gRoot

			gFocusRing.push()
            onCompletion?(0)
        }

		let hereCompletion = { (iHere: Zone) in
			self.hereZone = iHere

			gFocusRing.push()
			onCompletion?(0)
		}

        let name  = hereRecordName ?? kRootName

        if  name == kRootName {

            // //////////////////////
            // first time for user //
            // //////////////////////

            rootCompletion()

        } else if let here = maybeZoneForRecordName(name) {
            hereCompletion(here)
        } else {
            let recordID = CKRecord.ID(recordName: name)

            self.assureRecordExists(withRecordID: recordID, recordType: kZoneType) { (iHereRecord: CKRecord?) in
                if  iHereRecord == nil || iHereRecord?[kpZoneName] == nil {
                    rootCompletion()
                } else {
                    let    here = self.zone(for: iHereRecord!)
                    here.record = iHereRecord

                    here.maybeNeedChildren()
                    here.maybeNeedRoot()
                    here.fetchBeforeSave()
                    hereCompletion(here)
                }
            }
        }
    }
    
    
    func establishRoots(_ onCompletion: IntClosure?) {
		var establishRootAt: IntClosure?     // pre-declare so can recursively call from within it
        let         rootIDs: [ZRootID]   = [.favorites, .destroy, .trash, .graph, .lost]
        establishRootAt                  = { iIndex in
            if iIndex >= rootIDs.count {
                onCompletion?(0)
            } else {
                let      rootID = rootIDs[iIndex]
                let  recordName = rootID.rawValue
                var        name = self.databaseID.userReadableString + " " + recordName
                let recurseNext = { establishRootAt?(iIndex + 1) }

                switch rootID {
                case .favorites: if gFavoritesRoot        != nil || self.databaseID != .mineID { recurseNext(); return } else { name = kFavoritesName }
                case .graph:     if self.rootZone         != nil                               { recurseNext(); return } else { name = kFirstIdeaTitle }
                case .lost:      if self.lostAndFoundZone != nil                               { recurseNext(); return }
                case .trash:     if self.trashZone        != nil                               { recurseNext(); return }
                case .destroy:   if self.destroyZone      != nil                               { recurseNext(); return }
                }

                self.establishRootFor(name: name, recordName: recordName) { iZone in
                    if  rootID != .graph {
                        iZone.directAccess = .eProgenyWritable
                    }

                    switch rootID {
                    case .favorites: gFavoritesRoot        = iZone
                    case .destroy:   self.destroyZone      = iZone
                    case .trash:     self.trashZone        = iZone
                    case .graph:     self.rootZone         = iZone
                    case .lost:      self.lostAndFoundZone = iZone
                    }

                    recurseNext()
                }
            }
        }

        establishRootAt?(0)
    }


    func establishRootFor(name: String, recordName: String, _ onCompletion: ZoneClosure?) {
        let recordID = CKRecord.ID(recordName: recordName)

        assureRecordExists(withRecordID: recordID, recordType: kZoneType) { (iRecord: CKRecord?) in
            var record  = iRecord
            if  record == nil {
                record  = CKRecord(recordType: kZoneType, recordID: recordID)       // will create
            }

            let           zone = self.zone(for: record!, requireFetch: false)       // get / create
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


    func subscribe(_ onCompletion: IntClosure?) {
        if  cloudUnavailable {
            onCompletion?(0)
        } else {
            let classNames = [kZoneType, kTraitType, kManifestType]
            var      count = classNames.count

            onCompletion?(-1)
            for className: String in classNames {
                let    predicate :                     NSPredicate = NSPredicate(value: true)
                let subscription :                  CKSubscription = CKQuerySubscription(recordType: className, predicate: predicate, options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion])
                let  information : CKSubscription.NotificationInfo = CKSubscription.NotificationInfo()
                information                  .alertLocalizationKey = "new Thoughtful data has arrived";
				information            .shouldSendContentAvailable = true
                information                           .shouldBadge = true
                subscription                     .notificationInfo = information

                database!.save(subscription, completionHandler: { (iSubscription: CKSubscription?, iSubscribeError: Error?) in
                    gAlerts.alertError(iSubscribeError) { iHasError in
                        if iHasError {
                            gControllers.signalFor(iSubscribeError as NSObject?, regarding: .eError)
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
                    // icloud does not store this value, sigh
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
            let  type: String  = NSStringFromClass(Swift.type(of: object)) as String
            let query: CKQuery = CKQuery(recordType: type, predicate: predicate)

            database?.perform(query, inZoneWith: nil) { (iResults: [CKRecord]?, performanceError: Error?) in
                gAlerts.detectError(performanceError) { iHasError in
                    if iHasError {
                        gControllers.signalFor(performanceError as NSObject?, regarding: .eError)
                    } else {
                        let                 record: CKRecord = (iResults?[0])!
                        object.record?[valueForPropertyName] = (record as! CKRecordValue)

                        self.redrawGraph()
                    }
                }
            }
        }
    }

}

