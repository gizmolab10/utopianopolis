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

	var    addedToLevels = [Int : ZRecordsArray] ()
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

		FOREBACKGROUND { [self] in     // not stall foreground processor
            database?.add(operation)
        }
    }

	func invokeOperation(for identifier: ZOperationID, cloudCallback: AnyClosure?) {
		switch identifier { // inner switch
			case .oHere:             establishHere                  (cloudCallback)
			case .oRoots:            establishRoots     (identifier, cloudCallback)
			case .oManifest:         establishManifest  (identifier, cloudCallback)
			case .oResolveMissing:   resolveMissing                 (cloudCallback)
			case .oResolve:          resolve                        (cloudCallback)
			case .oAdopt:            assureAdoption                 (cloudCallback)
			default:                                                 cloudCallback?(0) // empty operations (e.g., .oStartUp and .oFinishUp)
		}
	}

	func finishCreatingManagedObjects(_ onCompletion: IntClosure?) {
		gCoreDataStack.finishCreating(for: databaseID) { [self] i in
			adoptAllNeedingAdoption()   // in case any orphans remain
			onCompletion?(i)
		}
	}

    func queryFor(_ recordType: String, with predicate: NSPredicate, properties: StringsArray, batchSize: Int = kBatchSize, cursor iCursor: CKQueryOperation.Cursor? = nil, onCompletion: RecordErrorClosure?) {
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

			operation.queryCompletionBlock = { [self] (iCursor, error) in
                if  let cursor = iCursor {
                    queryFor(recordType, with: predicate, properties: properties, cursor: cursor, onCompletion: onCompletion)  // recurse with cursor
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
		FOREGROUND { [self] in
			manifest = ZManifest.uniqueManifest(recordName: kManifestRootName, in: databaseID)
			manifest?.applyDeleted()
			onCompletion?(op)
		}
	}

    func establishHere(_ onCompletion: IntClosure?) {
        let    name = hereRecordName ?? kRootName
		currentHere = Zone.uniqueZone(recordName: name, in: databaseID)

		gRecents.push()
		onCompletion?(0)
    }

	enum ZRootID: String {
		case rootID      = "root"
		case trashID     = "trash"
		case destroyID   = "destroy"
		case recentsID   = "recents"
		case favoritesID = "favorites"
		case lostID      = "lost and found"
	}

    func establishRoots(_ op: ZOperationID, _ onCompletion: AnyClosure?) {
		var createFor: IntClosure?     // pre-declare so can recursively call from within it
		var   rootIDs: [ZRootID] = [.rootID, .trashID, .lostID, .destroyID]

		if  databaseID == .mineID {
			rootIDs.append(contentsOf: [.favoritesID, .recentsID])
		}

		createFor                = { [self] iIndex in
            if  iIndex >= rootIDs.count {
                onCompletion?(op)
            } else {
                let       rootID = rootIDs[iIndex]
                let   recordName = rootID.rawValue
				let       isMine = databaseID == .mineID
                var         name = databaseID.userReadableString + kSpace + recordName
                let  recurseNext = { createFor?(iIndex + 1) }

                switch rootID {
				case .favoritesID: if favoritesZone    != nil || !isMine { recurseNext(); return } else { name = kFavoritesRootName }
				case .recentsID:   if recentsZone      != nil || !isMine { recurseNext(); return } else { name = kRecentsRootName }
                case .rootID:      if rootZone         != nil            { recurseNext(); return } else { name = kFirstIdeaTitle }
                case .lostID:      if lostAndFoundZone != nil            { recurseNext(); return }
                case .trashID:     if trashZone        != nil            { recurseNext(); return }
                case .destroyID:   if destroyZone      != nil            { recurseNext(); return }
                }

				let root = Zone.uniqueZoneNamed(name, recordName: recordName, databaseID: databaseID)

				if  rootID != .rootID {
					root.directAccess = .eProgenyWritable
				}

				switch rootID {
					case .favoritesID: favoritesZone    = root
					case .recentsID:   recentsZone      = root
					case .destroyID:   destroyZone      = root
					case .trashID:     trashZone        = root
					case .lostID:      lostAndFoundZone = root
					case .rootID:      rootZone         = root
				}

				recurseNext()

            }
        }

		createFor?(0)
    }

}

