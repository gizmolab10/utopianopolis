//
//  ZBatches.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation

let gBatches       = ZBatches()
var gUser          :       ZUser? { return gBatches.user }
var gCurrentOp     : ZOperationID { return gBatches.currentOp }
var gHasFullAccess :         Bool { return gBatches.hasFullAccess }

enum ZBatchID: Int {
    case bRoot
    case bSync
    case bFocus
    case bStartUp
    case bUserTest
    case bBookmarks
    case bNewAppleID
	case bResumeCloud

    var shouldIgnore: Bool {
		switch self {
			case .bSync,
				 .bStartUp,
				 .bBookmarks,
				 .bNewAppleID: return false
			default:           return true
		}
    }

}

class ZBatches: ZOnboarding {

    class ZBatchCompletion: NSObject {
        var completion : BooleanClosure?
        var   snapshot : ZSnapshot

        override init() {
            snapshot = gSelecting.snapshot
        }

        convenience init(_ iClosure: @escaping BooleanClosure) {
            self.init()

            completion = iClosure
        }


        func fire() {
            completion?(snapshot.isSame)
        }
    }

    class ZBatch: NSObject {
        var       completions : [ZBatchCompletion]
        var        identifier :  ZBatchID
        var allowedOperations :  ZOpIDsArray { return gHasInternet ? operations : localBatchOperations }

        var operations: ZOpIDsArray {
			switch identifier {
				case .bResumeCloud: return [              .oMigrateFromCloud                 ]
				case .bSync:        return [              .oSavingLocalData                  ]
				case .bRoot:        return [.oRoots,      .oManifest                         ]
				case .bFocus:       return [.oRoots,                                         ]
				case .bBookmarks:   return [.oBookmarks                                      ]
				case .bStartUp:     return operationIDs(from: .oStartingUp,        to: .oDone)
				case .bNewAppleID:  return operationIDs(from: .oCheckAvailability, to: .oDone)
				case .bUserTest:    return operationIDs(from: .oObserveUbiquity,   to: .oFetchUserRecord)
			}
        }

        var localBatchOperations : ZOpIDsArray {
            var ids = ZOpIDsArray ()

            for operation in operations {
                if  operation.isLocal {
                    ids.append(operation)
                }
            }

            return ids
        }

        init(_ iID: ZBatchID, _ iCompletions: [ZBatchCompletion]) {
            completions = iCompletions
            identifier  = iID
        }

        func fireCompletions() {
            while let completion = completions.popLast() {
                completion.fire()
            }
        }

        func operationIDs(from: ZOperationID, to: ZOperationID, skipping: ZOpIDsArray = []) -> ZOpIDsArray {
            var operationIDs = ZOpIDsArray ()

            for value in from.rawValue...to.rawValue {
                var add = true

                for     skip in skipping {
                    if  skip.rawValue == value {
                        add = false
                        
                        break
                    }
                }

                if  add {
                    operationIDs.append(ZOperationID(rawValue: value)!)
                }
            }

            return operationIDs
        }

    }

    var      currentBatches = [ZBatch] ()
    var     deferredBatches = [ZBatch] ()
    var   currentDatabaseID : ZDatabaseID?
	var        currentBatch : ZBatch?
	var          statusText : String? { return currentOp.isDoneOp ? nil : currentOp.description + remainingOpsText }
	var    remainingOpsText : String  { let count = queue.operationCount; return count == 0 ? kEmpty : " (and \(count) others)" }
	var              isLate :   Bool  { return lastOpStart != nil && lastOpStart!.timeIntervalSinceNow < -30.0 }
	var          totalCount :    Int  { return currentBatches.count + deferredBatches.count }

    // MARK: - API
    // MARK: -

    func      root(_ onCompletion: @escaping BooleanClosure) { batch(.bRoot,        onCompletion) }
    func      sync(_ onCompletion: @escaping BooleanClosure) { batch(.bSync,        onCompletion) }
    func     focus(_ onCompletion: @escaping BooleanClosure) { batch(.bFocus,       onCompletion) }
	func   startUp(_ onCompletion: @escaping BooleanClosure) { batch(.bStartUp,     onCompletion) }
	func  userTest(_ onCompletion: @escaping BooleanClosure) { batch(.bUserTest,    onCompletion) }
	func bookmarks(_ onCompletion: @escaping BooleanClosure) { batch(.bBookmarks,   onCompletion) }

    func processNextBatch() {

        // 1. execute next current batch
        // 2. called by superclass, for each completion operation. fire completions and recurse
        // 3. no more current batches,                            transfer deferred and recurse
        // 4. no more batches, nothing to process                              turn off spinner

        FOREGROUND { [self] in
            if  let      batch = currentBatches.first {
                let operations = batch.allowedOperations
				currentBatch   = batch

                setupAndRun(operations) { [self] in        // 1.
                    batch.fireCompletions()                // 2.
                    maybeRemoveFirst()
                    processNextBatch()                     // recurse
                }
            } else if deferredBatches.count > 0 {
                transferDeferred()                         // 3.
                processNextBatch()                         // recurse
			} else {
				gSignal([.sData, .spStartupStatus])        // 4.
			}
        }
    }

    func batch(_ iID: ZBatchID, _ iCompletion: @escaping BooleanClosure) {
        if  iID.shouldIgnore {
            iCompletion(true) // true means no new data
//		} else  if  gStartupLevel == .firstTime {
//			gTimers.resetTimer(for: .tNeedUserAccess, withTimeInterval:  0.2, repeats: true) { iTimer in
//
//				// /////////////////////////////////////////////// //
//				// startup controller takes over via handle signal //
//				//                                                 //
//				// where only user input can change gStartupLevel  //
//				// /////////////////////////////////////////////// //
//
//				if  gStartupLevel != .firstTime {
//					iTimer.invalidate()
//					batch(iID, iCompletion)
//				}
//			}
		} else {
            let    current = getBatch(iID, from: currentBatches)
            let completion = [ZBatchCompletion(iCompletion)]
            let  startOver = currentBatches.count == 0

            // 1. is in deferral            -> add its completion to that deferred batch
            // 2. in neither                -> create new batch + append to current
            // 3. in current +  no deferred -> add its completion to that current batch
            // 4. in current + has deferred -> create new batch + append to deferred (other batches may change the state to what it expects)

            if  let deferred = getBatch(iID, from: deferredBatches) {
                deferred.completions.append(contentsOf: completion)         // 1.
            } else if current == nil {
                currentBatches .append(ZBatch(iID,      completion))        // 2.
            } else if deferredBatches.count > 0 {
                deferredBatches.append(ZBatch(iID,      completion))        // 3.
            } else {
                current?.completions.append(contentsOf: completion)         // 4.
            }

            if  startOver {
                processNextBatch()
            }
        }
    }

    // MARK: - internals
    // MARK: -

    func getBatch(_ iID: ZBatchID, from iList: [ZBatch]) -> ZBatch? {
        for batch in iList {
            if  iID == batch.identifier {
                return batch
            }
        }

        return nil
    }

    func maybeRemoveFirst() {
        if  currentBatches.count > 0 {
            currentBatches.removeFirst()
        }
    }

    func transferDeferred() {

        // /////////////////////////////////////////////////////////
        // if current list is empty, transfer deferred to current //
        // /////////////////////////////////////////////////////////

        if  currentBatches.count == 0 && deferredBatches.count > 0 {
            currentBatches  = deferredBatches
            deferredBatches = []
        }
    }

    override func invokeMultiple(for operationID: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping BooleanClosure) {

		// ///////////////////////////////////////////////////////////////
		//     first, allow onboarding superclass to perform block      //
		// iCompleted will be false if it does not handle the operation //
		//     thus app is no longer doing onboarding operationss       //
		// ///////////////////////////////////////////////////////////////

		super.invokeMultiple(for: operationID, restoreToID: restoreToID) { iCompleted in
            if  iCompleted {
                onCompletion(true)
            } else {
                let                      isMine = restoreToID == .mineID
				let               onlyCurrentID = (!gCloudStatusIsActive && !operationID.alwaysBoth)
				let  databaseIDs: [ZDatabaseID] = operationID.forMineOnly ? [.mineID] : onlyCurrentID ? [restoreToID] : kAllDatabaseIDs
				let                      isNoop = !gCloudStatusIsActive && onlyCurrentID && isMine && operationID != .oFavorites
                var invokeForIndex: IntClosure?                // declare closure first, so compiler will let it recurse
				invokeForIndex                  = { [self] index in

                    // //////////////////////////////
                    // always called in foreground //
                    // //////////////////////////////

                    if  operationID == .oFinishing || isNoop || index >= databaseIDs.count {
                        onCompletion(true)
                    } else {
                        currentDatabaseID = databaseIDs[index]      // if hung, it happened in currentDatabaseID

						do {
							try invokeOperation(for: operationID) { [self] (iResult: Any?) in

								let expectedOp = iResult as? ZOperationID
								let      error = iResult as? Error
								let     result = iResult as? Int
								let    isError = error      != nil
								let       isOp = expectedOp != nil

								if     isError || isOp || result == 0 {
									if isError || (isOp && (expectedOp != operationID)) {
										printOp("\(error!)")
									}

									invokeForIndex?(index + 1)         // recurse
								}
							}
						} catch {
							gTimers.assureCompletion(for: .tOperation, withTimeInterval: 0.1) {
								invokeForIndex?(index)
							}
						}
                    }
                }

                invokeForIndex?(0)
            }
        }
    }

	func load(into databaseID: ZDatabaseID, onCompletion: AnyClosure?) throws {
		switch gCDMigrationState {
			case .normal:  gLoadContext(into: databaseID, onCompletion: onCompletion)
			default: try gFiles.migrate(into: databaseID, onCompletion: onCompletion)
		}
	}

    override func invokeOperation(for identifier: ZOperationID, cloudCallback: AnyClosure?) throws {
        onCloudResponse = cloudCallback     // for retry cloud in tools controller

		switch identifier {
			case .oFavorites:                                                                      gFavorites.setup(cloudCallback)
			case .oSavingLocalData:  gSaveContext();                                                                cloudCallback?(0)
			case .oWrite:            try gFiles.writeToFile(from: currentDatabaseID);                               cloudCallback?(0)
			case .oLoadingIdeas:     try load(into:               currentDatabaseID!,                 onCompletion: cloudCallback)
			default: gRemoteStorage.cloud(for: currentDatabaseID!)?.invokeOperation(for: identifier, cloudCallback: cloudCallback)
		}
    }

}
