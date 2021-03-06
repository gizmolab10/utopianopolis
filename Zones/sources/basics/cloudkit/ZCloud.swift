//
//  ZCloud.swift
//  Seriously
//
//  Created by Jonathan Sand on 9/18/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

let gContainer = CKContainer(identifier: kCloudID)

class ZCloud: ZRecords {

	var    addedToLevels = [Int             : ZRecordsArray] ()
	var recordsToProcess = [String          : CKRecord]      () // accumulator for timer-based processing
	var   cloudZonesByID = [CKRecordZone.ID : CKRecordZone]  ()
	var         database :  CKDatabase? { return gRemoteStorage.databaseForID(databaseID) }
	var   refetchingName :       String { return "remember.\(databaseID.rawValue)" }
	var cloudUnavailable :         Bool { return !gHasInternet || (databaseID == .mineID && !gCloudStatusIsActive) }
	var    isRemembering :         Bool = false
	var currentOperation : CKOperation?
	var currentPredicate : NSPredicate?

    func configure(_ operation: CKDatabaseOperation) -> CKDatabaseOperation? {
        if  database != nil, gHasInternet {
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
			case .oBookmarks:        fetchBookmarks                 (cloudCallback)
			case .oCloud:            fetchCloudZones                (cloudCallback)
			case .oEmptyTrash:       emptyTrash                     (cloudCallback)
			case .oNeededIdeas:      fetchNeededIdeas               (cloudCallback)
			case .oParentIdeas:      fetchParentIdeas               (cloudCallback)
			case .oChildIdeas:       fetchChildIdeas                (cloudCallback)
			case .oFoundIdeas:       foundIdeas                     (cloudCallback)
			case .oLostIdeas:        fetchLostIdeas                 (cloudCallback)
			case .oNewIdeas:         fetchNewIdeas                  (cloudCallback)
			case .oRefetch:          refetchIdeas                   (cloudCallback)
			case .oHere:             establishHere                  (cloudCallback)
			case .oFetchAndMerge:    fetchAndMerge                  (cloudCallback)
			case .oRoots:            establishRoots     (identifier, cloudCallback)
			case .oManifest:         establishManifest  (identifier, cloudCallback)
			case .oSaveToCloud:      save                           (cloudCallback)
			case .oMigrateFromCloud: fetchMap                       (cloudCallback)
			case .oAllIdeas:         fetchAllIdeas                  (cloudCallback)
			case .oSubscribe:        subscribe                      (cloudCallback)
			case .oOwnedTraits:      fetchOwnedTraits               (cloudCallback)
			case .oAllTraits:        fetchAllTraits                 (cloudCallback)
			case .oUndelete:         undeleteAll                    (cloudCallback)
			case .oResolve:          resolve                        (cloudCallback)
			case .oAdopt:            assureAdoption                 (cloudCallback)
			case .oTraits:           fetchTraits                    (cloudCallback)
			case .oRecount:          recount(); fallthrough
			default:                                                 cloudCallback?(0) // empty operations (e.g., .oStartUp and .oFinishUp)
		}
	}

	func finishCreatingManagedObjects(_ onCompletion: IntClosure?) {
		gCoreDataStack.finishCreating(for: databaseID) { i in
			self.adoptAllNeedingAdoption()   // in case any orphans remain
			onCompletion?(i)
		}
	}

    // MARK:- push to cloud
    // MARK:-

    func save(_ onCompletion: IntClosure?) {
        let   saves = pullCKRecordsForZonesAndTraitsWithMatchingStates([.needsSave])
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
                            printDebug(.dError, String(describing: iError!) + "\n" + message)
                        }
                    }
                }
            }

            operation.modifyRecordsCompletionBlock = { (iSavedCKRecords, iDeletedRecordIDs, iError) in
                // deal with saved records marked as deleted

                FOREGROUND {
                    if  let destroyed = iDeletedRecordIDs {
                        if  destroyed.count > 0 { self.columnarReport("DESTROY (\(destroyed.count))", self.stringForRecordIDs(destroyed)) }
                        for recordID: CKRecordID in destroyed {
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
                            printDebug(.dError, String(describing: iError!))
                        }
                    }

                    self.fetchAndMerge { iCount in              // process merges caused (before now) by save oplock errors
                        if iCount == 0 {
                            self.save(onCompletion)             // process any remaining
                        }
                    }
                }
            }

			onCompletion?(1)
            start(operation)
        } else {
			if  gCurrentTimerID == .tSync {  // this else clause is easiest way to detect completion
				gCurrentTimerID  = nil       // remove "saving data" from status text in data details
			}

			onCompletion?(0)
        }
    }

    func emptyTrash(_ onCompletion: IntClosure?) {
//        let   predicate = NSPredicate(format: "zoneisInTrash = 1")
//        var toBeDeleted = CKRecordIDsArray()
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
//                let         deleted = self.maybeZRecordForCKRecord(iRecord) as? Zone ?? Zone.create(record: iRecord, databaseID: self.databaseID)
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
    
    func  assureRecordExists(withRecordID iCKRecordID: CKRecordID?, recordType: String?, onCompletion: @escaping RecordClosure) {
        detectIfRecordExists(withRecordID: iCKRecordID, recordType: recordType, mustCreate: true, onCompletion: onCompletion)
    }

    func detectIfRecordExists(withRecordID iCKRecordID: CKRecordID?, recordType: String?, mustCreate: Bool = false, onCompletion: @escaping RecordClosure) {
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

    func fetchRecord(for recordID: CKRecordID) {
        
        // //////////////////////////////////////
		// BUG: could be a trait or a deletion //
        // //////////////////////////////////////
		
        detectIfRecordExists(withRecordID: recordID, recordType: kZoneType) { iUpdatedRecord in
            if  let ckRecord = iUpdatedRecord, !ckRecord.isEmpty {
                let     zone = self.sureZoneForCKRecord(ckRecord)
                if ckRecord == zone.ckRecord {    // record data is new (zone for just updated it)
                    zone.addToParent() { iZone in
						gSignal(for: iZone, [.sRelayout])
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
                    gAlerts.alertError(error, predicate.description) { iHasError in     // noop if error is nil
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
		queryFor(kZoneType, with: predicate, properties: Zone.cloudProperties, batchSize: batchSize, onCompletion: onCompletion)
	}

	func queryForTraitsWith(_ predicate: NSPredicate, batchSize: Int = kBatchSize, onCompletion: RecordErrorClosure?) {
		queryFor(kTraitType, with: predicate, properties: ZTrait.cloudProperties, batchSize: batchSize, onCompletion: onCompletion)
	}

    func predicate(since iStart: Date?, before iEnd: Date?) -> NSPredicate {
        var predicate = NSPredicate(value: true)

        if  let start = iStart {
            predicate = NSPredicate(format: "modificationDate >= %@", start as NSDate)

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

	var neededTraitsPredicate: NSPredicate? {
		let recordIDs = recordIDsWithMatchingStates([.needsTraits], pull: true)

		if  recordIDs.count == 0 {
			return nil
		}

		var predicate = ""
		var separator = ""

		for recordID in recordIDs {
			predicate = String(format: "%@%@SELF CONTAINS \"%@\"", predicate, separator, recordID.recordName)
			separator = " AND "
		}

		return NSPredicate(format: predicate)
	}

    func bookmarkPredicate(specificTo iRecordIDs: CKRecordIDsArray) -> NSPredicate? {
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
		var retrieved = CKRecordsArray ()

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
			} else if gFilterOption.contains(.fNotes) {
				self.queryForTraitsWith(notesPredicate) { (iRecord, iError) in
					if  let ckRecord = iRecord {
						if !retrieved.contains(ckRecord) {
							retrieved.append(ckRecord)
						}
					} else {
						onCompletion?(retrieved as NSObject)
					}
				}
			} else {
				onCompletion?(retrieved as NSObject)
			}
        }
    }

    func fetchAndMerge(_ onCompletion: IntClosure?) {
        var recordIDs = recordIDsWithMatchingStates([.needsMerge])
        let     count = recordIDs.count

        if  count > 0, let           operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            var                   receivedByID = [CKRecord : CKRecordID?] ()
            operation               .recordIDs = recordIDs
            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
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
                                let identifier = iZone.ckRecordName,
                                !iZone.isARoot,
                                !memorables.contains(identifier) {
                                memorables.append(identifier)
                            }
                        }
                    }
                }

                scan(self.rootZone)
                scan(self.currentHere)
				scan(gFavorites.rootZone)

                self.columnarReport("REMEMBER (\(memorables.count))", "\(self.databaseID.rawValue)")
                setPreferencesString(memorables.joined(separator: kColonSeparator), for: self.refetchingName)

                self.isRemembering = false

                onCompletion?(0)
            }
        }
    }

    func refetchIdeas(_ onCompletion: IntClosure?) {
        if  let fetchables = getPreferencesString(for: refetchingName, defaultString: "")?.components(separatedBy: kColonSeparator) {
            for fetchable in fetchables {
                if fetchable != "" {
                    addCKRecord(CKRecord(for: fetchable), for: [.needsFetch])
                }
            }

            fetchNeededIdeas(onCompletion) // includes processing logic for retrieved records
        }
    }

    func foundIdeas(_ onCompletion: IntClosure?) {
        let states = [ZRecordState.needsFound]

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iRecordName in
            if  let zone = maybeZoneForRecordName(iRecordName) {
                clearRecordName(iRecordName, for: states)
                lostAndFoundZone?.addAndReorderChild(zone)
            }

			return false
        }

        onCompletion?(0)
    }

    func fetchLostIdeas(_ onCompletion: IntClosure?) {
        let    format = kpRecordName + " != \"" + kRootName + kDoubleQuote
        let predicate = NSPredicate(format: format)
        var   fetched = CKRecordsArray ()

        self.queryForZonesWith(predicate, batchSize: kMaxBatchSize) { (iRecord, iError) in
            if  let ckRecord      = iRecord {
                if  !kAutoGeneratedNames.contains(ckRecord.recordID.recordName),
                    !fetched.contains(ckRecord) {
                    fetched.append(ckRecord)
                }
            } else { // nil means: we already received full response from cloud for this particular fetch
                FOREGROUND {
                    var               lost = self.createRandomLost()
                    var          parentIDs = CKRecordIDsArray ()
                    var             toLose = CKRecordsArray ()
                    var childrenRecordsFor = [CKRecordID : CKRecordsArray] ()
                    let         isOrphaned = { (iCKRecord: CKRecord) -> Bool in
                        if  let  parentRef = iCKRecord[kpParent] as? CKReference {
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
                        if  isOrphaned(ckRecord) {
                            toLose.append(ckRecord)
                        }
                    }

                    addToLost(toLose)

                    if childrenRecordsFor.count == 0 {
                        onCompletion?(0)
                    } else {
                        var missingIDs = CKRecordIDsArray ()
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

                                self.fetchIdeas(needed: seekParentIDs) { iFetchedParents in
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

    func fetch(for type: String, properties: [String], since start: Date, before end: Date? = nil, _ onCompletion: RecordsClosure?) {
        let predicate = self.predicate(since: start, before: end)
        var retrieved = CKRecordsArray ()

        queryFor(type, with: predicate, properties: properties, batchSize: kBatchSize) { (iRecord, iError) in
            if  iError != nil {
				if  let middle = start.mid(to: end) {
					self.fetch(for: type, properties: properties, since: start, before: middle) { iCKRecords in         // error, fetch first half
						retrieved.appendUnique(contentsOf: iCKRecords)

						self.fetch(for: type, properties: properties, since: middle, before: end) { iCKRecords in       // fetch second half
							retrieved.appendUnique(contentsOf: iCKRecords)

							onCompletion?(retrieved)
						}
					}
				}
			} else if let ckRecord = iRecord {
				retrieved.appendUnique(item: ckRecord)
			} else { // nil means: we already received full response from cloud for this particular fetch
                onCompletion?(retrieved)
            }
        }
    }

    func createZRecordsAsync(from iCKRecords: CKRecordsArray, _ onCompletion: Closure? = nil) {
		let dbID = databaseID

		for record in iCKRecords {
			recordsToProcess[record.recordID.recordName] = record // assures no duplication
		}

		if  recordsToProcess.count > 0,
			let timerID = ZTimerID.recordsTimerID(for: dbID) {
			gTimers.assureCompletion(for: timerID, now: true, withTimeInterval: 0.2) {
				while self.recordsToProcess.count > 0 {
					if  let      key = self.recordsToProcess.keys.first,
						let ckRecord = self.recordsToProcess.removeValue(forKey: key) {

						switch ckRecord.recordType {
							case kZoneType:    Zone.createAsync(record: ckRecord, databaseID: dbID) { zone  in  zone.adopt() }
							case kTraitType: ZTrait.createAsync(record: ckRecord, databaseID: dbID) { trait in trait.adopt() }
							default: break
						}

						try gThrowOnUserActivity()
					}
				}

				self.adoptAllNeedingAdoption()
				onCompletion?()
			}
		}
    }

	// N.B. this is really gawdawful slow
	func fetchMap(_ onCompletion: IntClosure?) {
		rootZone?         .needProgeny()
		trashZone?        .needProgeny()
		destroyZone?      .needProgeny()
		lostAndFoundZone? .needProgeny()

		if  databaseID == .mineID {
			recentsZone?  .needProgeny()
			favoritesZone?.needProgeny()
		}

		fetchChildIdeas(onCompletion)
	}

	func fetchAllIdeas(_ onCompletion: IntClosure?) { fetchSince(kDevelopmentStartDate, onCompletion) }
    func fetchNewIdeas(_ onCompletion: IntClosure?) { fetchSince(lastSyncDate,          onCompletion) }

    func fetchSince(_ date: Date, _ onCompletion: IntClosure?) {
        // for zones, traits, destroy
        // if date is nil, fetch all

		fetch(for: kZoneType, properties: Zone.cloudProperties, since: date) { iZoneCKRecords in                    // start the fetch: first zones
			self.createZRecordsAsync(from: iZoneCKRecords) {
				gNeedsRecount = true

				self.fetch(for: kTraitType, properties: ZTrait.cloudProperties, since: date) { iTraitCKRecords in   // on async response: then traits
					FOREGROUND {
						self.createZRecordsAsync(from: iTraitCKRecords) {
							self.finishCreatingManagedObjects(onCompletion)
						}
					}
				}
			}
		}
    }

    func fetchNeededIdeas(_ onCompletion: IntClosure?) {
        let needed = recordIDsWithMatchingStates([.needsFetch, .requiresFetchBeforeSave], pull: true)

		if  needed.count == 0 {
			FOREGROUND {
				onCompletion?(0)
			}
		} else {
			fetchIdeas(needed: needed) { iCKRecords in
				FOREGROUND {
					if  iCKRecords.count == 0 {
						gNeedsRecount = true

						onCompletion?(0)
					} else {
						self.createZRecordsAsync(from: iCKRecords) {
							self.fetchNeededIdeas(onCompletion)                            // process remaining
						}
					}
				}
			}
		}
    }

    func fetchIdeas(needed:   CKRecordIDsArray, _ onCompletion: RecordsClosure?) {
        var   IDsToFetchNow = CKRecordIDsArray ()
        var       retrieved = CKRecordsArray ()
        var IDsToFetchLater = needed
        var    fetchClosure : Closure?  // declare unassigned so can be called recursively

        fetchClosure = {
            let count = IDsToFetchLater.count
            IDsToFetchNow = IDsToFetchLater

            if  count == 0 {

				// ///////
				// DONE //
				// ///////
				
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

					// //////////
					// RECURSE //
					// //////////

					fetchClosure?()
                }
            }
        }

        fetchClosure?()
    }

    func reliableFetch(needed: CKRecordIDsArray, properties: [String] = Zone.cloudProperties, _ onCompletion: RecordsClosure?) {
        let count = needed.count

        if  count > 0, let operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            var            retrieved = CKRecordsArray ()
            operation   .desiredKeys = properties
            operation     .recordIDs = needed

            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
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

    func fetchParentIdeas(_ onCompletion: IntClosure?) {
        let fetchingStates: [ZRecordState] = [.needsWritable, .needsParent, .needsColor, .needsRoot]
        let               missingParentIDs = parentIDsWithMatchingStates(fetchingStates)
        let                    childrenIDs = recordIDsWithMatchingStates(fetchingStates)
        let                          count = missingParentIDs.count

        if  count > 0, let       operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            var         fetchedRecordsByID = [CKRecord : CKRecordID?] ()
            operation           .recordIDs = missingParentIDs

            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
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
                            maybe  = self.sureZoneForCKRecord(fetchedRecord)
                        }

                        if  let    fetched = maybe,     // always not nil
                            let recordName = fetched.ckRecordName {

                            fetched.maybeNeedChildren()

                            for childID in childrenIDs {
                                if  let   child = self.maybeZoneForRecordID(childID), !fetched.spawnedBy(child),
                                    recordName == child.parentZone?.ckRecordName,
                                    let       r = child.ckRecord {
                                    let  states = self.states(for: r)

                                    if  child.isARoot || child == fetched {
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
                    self.adoptAllNeedingAdoption()
                    self.fetchParentIdeas(onCompletion)   // process remaining
                }
            }

            start(operation)
        } else {
            onCompletion?(0)
        }
    }

	func fetchChildIdeas(visited: [String] = [], final: Bool = false, _ onCompletion: IntClosure?) {
//		if  databaseID == .mineID { onCompletion?(0) }
		let fetchNeeded = referencesWithMatchingStates([.needsChildren, .needsProgeny], batchSize: kSmallBatchSize)
		let  reallyNeed = fetchNeeded.filter { !visited.contains($0.recordID.recordName) }
        let       count = reallyNeed.count

		if  count == 0 {                                               // nothing more to fetch, call existence closures
			if !final {
				finishCreatingManagedObjects { i in                    // existence closures may mark more zones as needing progeny
					self.fetchChildIdeas(visited: visited, final: true, onCompletion)    // recurse to process any remaining
				}
			} else {
				onCompletion?(0)
			}
		} else {
            let        predicate = NSPredicate(format: "parent IN %@", reallyNeed)
            let     destroyedIDs = recordIDsWithMatchingStates([.needsDestroy])
			let   trackingLevels = gPrintModes.contains(.dLevels)
            var retrievedRecords = CKRecordsArray ()
			let      parentNames = reallyNeed.map { $0.recordID.recordName }
			var                v = visited

			v.appendUnique(contentsOf: parentNames)

			remove(states: [.needsChildren, .needsProgeny], from: fetchNeeded)
			add   (states: [.needsCount],                     to: reallyNeed)

            queryForZonesWith(predicate, batchSize: kMaxBatchSize) { (iRecord, iError) in
                if  let ckRecord = iRecord {
					if !v.contains(ckRecord.recordID.recordName) { // avoid repeats
						retrievedRecords.appendUnique(item: ckRecord)
					}
				} else {          // retrievedRecords is all we get for this query
                    FOREGROUND {
						printDebug(.dFetch, "\(self.databaseID.identifier) + \(retrievedRecords.count)")

						// //////////////////////////////////////////////////// //
						// we are now in the foreground and can mutate the heap //
						//              for each retrieved record               //
						// //////////////////////////////////////////////////// //

						for (index, retrievedRecord) in retrievedRecords.enumerated() {

							// ///////////////////////////////////////// //
							// create the zone from the retrieved record //
							// ///////////////////////////////////////// //

							if  destroyedIDs.contains(retrievedRecord.recordID) {
								printDebug(.dCloud, "DESTROYED: \(retrievedRecord.recordID) at \(index)")
							} else {
								printDebug(.dCloud, "\(index) of \(retrievedRecords.count)")

								self.zoneForCKRecordAsync(retrievedRecord) { retrievedZone in

									// ////////////////////////////////////////////////// //
									// this block invoked by finishCreatingManagedObjects //
									//     possibly long after onCompletion is called     //
									// ////////////////////////////////////////////////// //

									self.processChildZone(retrievedZone, parentNames)
								}
							}
						}

						// //////////////////// //
						// for debugging levels //
						// //////////////////// //

						if  trackingLevels, retrievedRecords.count > 0 {
							var separator = ""
							var    string = ""

							for level in 0...self.maxLevel {
								if  let records = self.addedToLevels[level] {
									string.append("\(separator)\(level):\(records.count)")
									separator   = ", "
								}
							}

							if  string.count > 0 {
								printDebug(.dLevels, "(\(self.databaseID.identifier)) \(string)")
							}
						}

						self.fetchChildIdeas(visited: v, onCompletion)    // recurse to process any remaining
                    }
                }
            }
        }
    }

	func processChildZone(_ retrievedZone: Zone, _ neededNames: [String]) {
		if  let parent = retrievedZone.parentZone {
			if  retrievedZone == parent {
				retrievedZone.needDestroy()           // self-parenting causes infinite recursion (HANG)
			} else if retrievedZone.isARoot {
				retrievedZone.orphan()                // avoid infinite recursion (HANG) ... a root can NOT have a parent, by definition
				retrievedZone.allowSaveWithoutFetch()
				retrievedZone.needSave()
			} else {
				if  let parentName = parent.ckRecordName,
					neededNames.contains(parentName) {
					retrievedZone.needProgeny()       // for recursing
					retrievedZone.bookmarkTarget?.needProgeny()
					// note: this code may be executed AFTER the on completion closure is called !!!!!!
				}

				if  let targetOfRetrieved = retrievedZone.bookmarkTarget {

					// //////////////////////////////////////////////////
					// bookmark targets need writable, color and fetch //
					// //////////////////////////////////////////////////

					targetOfRetrieved.needFetch()
					targetOfRetrieved.maybeNeedColor()
					targetOfRetrieved.maybeNeedWritable()
				}

				parent.addChildAndRespectOrder(retrievedZone)

				let level = retrievedZone.level

				self.updateMaxLevel(with: level)

				if  gPrintModes.contains(.dLevels) {
					var wereAdded = self.addedToLevels[level] ?? ZRecordsArray()
					if  wereAdded.appendUnique(item: retrievedZone) {
						self.addedToLevels[level] = wereAdded
					}
				}
			}
		}
	}

	func establishManifest(_ op: ZOperationID, _ onCompletion: AnyClosure?) {
        var retrieved = CKRecordsArray ()
        let predicate = NSPredicate(value: true)

        queryFor(kManifestType, with: predicate, properties: ZManifest.cloudProperties) { (iRecord, iError) in
            if let ckRecord = iRecord {
                if !retrieved.contains(ckRecord) {
                    retrieved.append(ckRecord)
                }
            } else { // nil means done
                FOREGROUND {
                    for ckRecord in retrieved {
                        if  self.manifest == nil {
                            self.manifest  = ZManifest.create(record: ckRecord, databaseID: self.databaseID)
                        } else {
                            self.manifest?.useBest(record: ckRecord)
                        }
                        
                        self.manifest?.apply()
                    }
                    
                    self.columnarReport("    \(self.manifest?.deletedRecordNames?.count ?? 0)", "\(self.databaseID.rawValue)")
                    onCompletion?(op)
                }
            }
        }
	}

	func fetchTraits     (_ onCompletion: IntClosure?) { fetchTraits(using: neededTraitsPredicate,                                    onCompletion) }
	func fetchAllTraits  (_ onCompletion: IntClosure?) { fetchTraits(using: NSPredicate(value: true),                                 onCompletion) }
	func fetchOwnedTraits(_ onCompletion: IntClosure?) { fetchTraits(using: NSPredicate(format: "owner IN %@", allProgenyReferences), onCompletion) }

	func fetchTraits(using predicate: NSPredicate?, _ onCompletion: IntClosure?) {
		var retrieved = CKRecordsArray ()

		if  predicate == nil {
			onCompletion?(0)
		} else {
			queryFor(kTraitType, with: predicate!, properties: ZTrait.cloudProperties) { (iRecord, iError) in
				if  let ckRecord = iRecord {
					retrieved.appendUnique(item: ckRecord)
				} else { // nil means done
					FOREGROUND {
						for ckRecord in retrieved {
							ZTrait.createAsync(record: ckRecord, databaseID: self.databaseID) { tRecord in }
						}

						self.finishCreatingManagedObjects(onCompletion) // calls adopt all
					}
				}
			}
		}
	}

    func fetchBookmarks(_ onCompletion: IntClosure?) {
        let targetIDs = recordIDsWithMatchingStates([.needsBookmarks], pull: true)
        if let predicate = bookmarkPredicate(specificTo: targetIDs) {
            let specified = targetIDs.count != 0
            var retrieved = CKRecordsArray ()

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
                                        if  target.isARoot || target == parent { // no roots have a parent, by definition
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
        let name  = hereRecordName ?? kRootName
        if  name == kRootName {

            // //////////////////////
            // first time for user //
            // //////////////////////

			self.hereZoneMaybe = gRoot

			gRecents.push()
			onCompletion?(0)

        } else if let here = maybeZoneForRecordName(name) {
			self.currentHere = here

			here.updateInstanceProperties()
			gRecents.push()
			onCompletion?(0)
        } else {
            let recordID = CKRecordID(recordName: name)

            self.assureRecordExists(withRecordID: recordID, recordType: kZoneType) { (iHereRecord: CKRecord?) in
                if  iHereRecord == nil || iHereRecord?[kpZoneName] == nil {
					self.hereZoneMaybe = gRoot

					gRecents.push()
					onCompletion?(0)
                } else {
                    let         here = self.sureZoneForCKRecord(iHereRecord!)
					self.currentHere = here

					here.updateInstanceProperties()
                    here.maybeNeedChildren()
                    here.maybeNeedRoot()
                    here.fetchBeforeSave()
					gRecents.push()
					onCompletion?(0)
                }
            }
        }
    }
    
    
    func establishRoots(_ op: ZOperationID, _ onCompletion: AnyClosure?) {
		var createFor: IntClosure?     // pre-declare so can recursively call from within it
		var   rootIDs: [ZRootID] = [.mapID, .trashID, .lostID, .destroyID]

		if  databaseID == .mineID {
			rootIDs.append(contentsOf: [.favoritesID, .recentsID])
		}

		createFor                = { iIndex in
            if  iIndex >= rootIDs.count {
                onCompletion?(op)
            } else {
                let       rootID = rootIDs[iIndex]
                let   recordName = rootID.rawValue
				let       isMine = self.databaseID == .mineID
                var         name = self.databaseID.userReadableString + " " + recordName
                let  recurseNext = { createFor?(iIndex + 1) }

                switch rootID {
				case .favoritesID: if self.favoritesZone    != nil || !isMine { recurseNext(); return } else { name = kFavoritesRootName }
				case .recentsID:   if self.recentsZone      != nil || !isMine { recurseNext(); return } else { name = kRecentsRootName }
                case .mapID:       if self.rootZone         != nil            { recurseNext(); return } else { name = kFirstIdeaTitle }
                case .lostID:      if self.lostAndFoundZone != nil            { recurseNext(); return }
                case .trashID:     if self.trashZone        != nil            { recurseNext(); return }
                case .destroyID:   if self.destroyZone      != nil            { recurseNext(); return }
                }

                self.establishRootFor(name: name, recordName: recordName) { iZone in
                    if  rootID != .mapID {
                        iZone.directAccess = .eProgenyWritable
                    }

					switch rootID {
						case .favoritesID: self.favoritesZone    = iZone
						case .recentsID:   self.recentsZone      = iZone
						case .destroyID:   self.destroyZone      = iZone
						case .trashID:     self.trashZone        = iZone
						case .lostID:      self.lostAndFoundZone = iZone
						case .mapID:       self.rootZone         = iZone
					}

                    recurseNext()
                }
            }
        }

		createFor?(0)
    }

    func establishRootFor(name: String, recordName: String, _ onCompletion: ZoneClosure?) {
        let recordID = CKRecordID(recordName: recordName)

        assureRecordExists(withRecordID: recordID, recordType: kZoneType) { (iRecord: CKRecord?) in
            var record  = iRecord
            if  record == nil {
                record  = CKRecord(recordType: kZoneType, recordID: recordID)       // will create
            }

            let           zone = self.sureZoneForCKRecord(record!)                  // get / create
            zone       .parent = nil                                                // roots have no parent

            if  zone.zoneName == nil {
                zone.zoneName  = name                                               // was created

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
                information                  .alertLocalizationKey = "new Seriously data has arrived";
				information            .shouldSendContentAvailable = true
                information                           .shouldBadge = true
                subscription                     .notificationInfo = information

                database!.save(subscription, completionHandler: { (iSubscription: CKSubscription?, iSubscribeError: Error?) in
                    gAlerts.alertError(iSubscribeError) { iHasError in
                        if iHasError {
							gSignal(for: iSubscribeError as NSObject?, [.sError])
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
        if  let   record = object.ckRecord, database != nil {
            let oldValue = record[property] as? NSObject

            if  oldValue        != value {
                record[property] = value as? CKRecordValue

                if  let string = value as? String, string == kNullLink {
                    // icloud does not store this value, sigh
//                } else if object.canSaveWithoutFetch {
//                    object.needSave()
                } else {
                    object.maybeNeedMerge()
                }
            }
        }
    }

    func getFromObject(_ object: ZRecord, valueForPropertyName: String) {
        if  database          != nil &&
            object  .ckRecord != nil {
            let      predicate = NSPredicate(value: true)
            let  type: String  = NSStringFromClass(Swift.type(of: object)) as String
            let query: CKQuery = CKQuery(recordType: type, predicate: predicate)

            database?.perform(query, inZoneWith: nil) { (iResults: CKRecordsArray?, performanceError: Error?) in
                gAlerts.detectError(performanceError) { iHasError in
                    if iHasError {
						gSignal(for: performanceError as NSObject?, [.sError])
                    } else {
                        let                 record: CKRecord = (iResults?[0])!
                        object.ckRecord?[valueForPropertyName] = (record as! CKRecordValue)

                        gRedrawMaps()
                    }
                }
            }
        }
    }

}

