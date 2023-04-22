//
//  ZCloud.swift
//  Seriously
//
//  Created by Jonathan Sand on 9/18/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

var gCloudContainer : CKContainer? { return gCKRepositoryID.cloudKitID == nil ? nil : CKContainer(identifier: gCKRepositoryID.cloudKitID!) }

class ZCloud: ZRecords {

	var    addedToLevels = [Int : ZRecordsArray] ()
	var currentOperation : CKOperation?
	var currentPredicate : NSPredicate?
	var         database :  CKDatabase? { return gRemoteStorage.databaseForID(databaseID) }
	var   refetchingName :      String  { return "remember.\(databaseID.rawValue)" }
	var    isRemembering :        Bool  = false

    func configure(_ operation: CKDatabaseOperation) -> CKDatabaseOperation? {
		guard let c = gCloudContainer, database != nil, gHasInternet else {
			return nil
		}

		let                        configuration = operation.configuration ?? CKOperation.Configuration()
		configuration.timeoutIntervalForResource = kRemoteTimeout
		configuration.timeoutIntervalForRequest  = kRemoteTimeout
		configuration                 .container = c
		operation                 .configuration = configuration
		operation              .qualityOfService = .background

		return operation
	}

    func start(_ operation: CKDatabaseOperation) {
        currentOperation = operation

//		BACKGROUND { [self] in     // not stall foreground processor
            database?.add(operation)
//        }
    }

	func invokeOperation(for identifier: ZOperationID, cloudCallback: AnyClosure?) {
		switch identifier {
			case .oManifest:         establishManifest  (identifier, cloudCallback)
			case .oRoots:            establishRoots     (identifier, cloudCallback)
			case .oHere:             establishHere                  (cloudCallback)
			case .oAdopt:            assureAdoption                 (cloudCallback)
			case .oResolve:          resolve                        (cloudCallback)
			case .oResolveMissing:   resolveMissing                 (cloudCallback)
			default:                                                 cloudCallback?(0) // empty operations (e.g., .oStartUp and .oFinishUp)
		}
	}

	func finishCreatingManagedObjects(_ onCompletion: IntClosure?) {
		gCoreDataStack.finishCreating(for: databaseID) { [self] i in
			adoptAllNeedingAdoption()   // in case any orphans remain
			onCompletion?(i)
		}
	}

	func queryFor(_ recordType: String, with predicate: NSPredicate, properties: StringsArray?, sortedBy: [NSSortDescriptor]? = nil, batchSize: Int = kBatchSize, cursor iCursor: CKQueryOperation.Cursor? = nil, onCompletion: RecordErrorClosure?) {
        currentPredicate                 = predicate
        if  var                operation = configure(CKQueryOperation()) as? CKQueryOperation {
            if  let               cursor = iCursor {
                operation                = CKQueryOperation.init(cursor: cursor)
            } else {
                operation         .query = CKQuery(recordType: recordType, predicate: predicate)
            }

            operation           .desiredKeys = properties
            operation          .resultsLimit = batchSize
			operation.query?.sortDescriptors = sortedBy
            operation    .recordFetchedBlock = { iRecord in                                 // TODO: recordMatchedBlock
                onCompletion?(iRecord, nil)
            }

			operation.queryCompletionBlock = { [self] iCursor, error in                 // TODO: queryResultBlock
                if  let cursor = iCursor {
                    queryFor(recordType, with: predicate, properties: properties, batchSize: batchSize, cursor: cursor, onCompletion: onCompletion)  // recurse with cursor
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
        let    tokens = searchString.components(separatedBy: kSpace)
        var    string = kEmpty
        var separator = kEmpty

        for token in tokens {
            if  token    != kEmpty {
                string    = "\(string)\(separator)SELF CONTAINS \"\(token.escaped)\""
                separator = " AND "
            }
        }

        return string == kEmpty ? nil : NSPredicate(format: string)
    }

	func noteSearchPredicateFrom(_ searchString: String) -> NSPredicate? {
		let    tokens = searchString.components(separatedBy: kSpace)
		var    string = kEmpty
		var separator = kEmpty

		for token in tokens {
			if  token    != kEmpty {
				string    = String(format: "%@%@SELF.strings CONTAINS \"%@\"", string, separator, token)
				separator = " AND "
			}
		}

		return string == kEmpty ? nil : NSPredicate(format: string)
	}

	func establishManifest(_ op: ZOperationID, _ onCompletion: AnyClosure?) {
		if  manifest == nil {
			FOREGROUND { [self] in
				manifest = ZManifest.uniqueManifest(recordName: kManifestRootName, in: databaseID)
				manifest?.applyDeleted()
				onCompletion?(op)
			}
		}
	}

    func establishHere(_ onCompletion: IntClosure?) {
		if  let name  = hereRecordName {
			if  name == kRootName, let root = rootZone {
				currentHere = root
			} else {
				currentHere = Zone.uniqueZone(recordName: name, in: databaseID)
			}
		}

		onCompletion?(0)
    }

    func establishRoots(_ op: ZOperationID, _ onCompletion: AnyClosure?) {
		var createFor: IntClosure?     // pre-declare so can recursively call from within it
		var   rootIDs: [ZRootID] = [.rootID, .trashID, .lostID, .destroyID]

		if  databaseID == .mineID {
			rootIDs.append(contentsOf: [.favoritesID])
		}

		createFor                = { [self] index in
            if  index           >= rootIDs.count {
                onCompletion?(op)
            } else {
                let       rootID = rootIDs[index]
                let   recordName = rootID.rawValue
				let       isMine = databaseID == .mineID
                var         name = databaseID.userReadableString + kSpace + recordName
                let  recurseNext = { createFor?(index + 1) }

                switch rootID {
				case .favoritesID: if favoritesZone    != nil || !isMine { recurseNext(); return } else { name = kFavoritesRootName }
                case .rootID:      if rootZone         != nil            { recurseNext(); return } else { name = kFirstIdeaTitle }
                case .lostID:      if lostAndFoundZone != nil            { recurseNext(); return }
                case .trashID:     if trashZone        != nil            { recurseNext(); return }
                case .destroyID:   if destroyZone      != nil            { recurseNext(); return }
                }

				if  !isRootSet(for: rootID) {

					// root has not been assigned to its internal variable (setRoot below will do this)
					// so try to find it in the freshly loaded ideas

					let root              = lookupRoot(for: rootID) ?? Zone.uniqueZoneNamed(name, recordName: recordName, databaseID: databaseID, checkCDStore: true)
					if  rootID           != .rootID {
						root.directAccess = .eProgenyWritable
					}
					
					FOREGROUND { [self] in
						setRoot(root, for: rootID)
					}
				}

				recurseNext()

            }
        }

		createFor?(0)
    }

}
