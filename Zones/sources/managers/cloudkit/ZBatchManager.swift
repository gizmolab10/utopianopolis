//
//  ZBatchManager.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation


let gBatchManager = ZBatchManager()
var gUser: ZUser? { return gBatchManager.user }


enum ZBatchID: Int {
    case saveToCloud
    case root
    case sync
    case focus
    case startUp
    case refetch
    case parents
    case children
    case families
    case undelete
    case finishUp
    case userTest
    case bookmarks
    case fetchLost
    case emptyTrash
    case newAppleID
    case resumeCloud

    var shouldIgnore: Bool {
        switch self {
        case .saveToCloud:                                                           return gCloudAccountIsActive
        case .sync, .startUp, .refetch, .finishUp, .newAppleID, .resumeCloud: return false
        default:                                                              return true
        }
    }

}


class ZBatchManager: ZOnboardingManager {


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
            completion?(snapshot == gSelecting.snapshot)
        }
    }


    class ZBatch: NSObject {
        var       completions : [ZBatchCompletion]
        var        identifier :  ZBatchID
        var allowedOperations : [ZOperationID] { return gHasInternet ? operations : localOperations }


        var operations: [ZOperationID] {
            switch identifier {
            case .saveToCloud:        return [                       .saveToCloud         ]
            case .sync:        return [            .fetch,    .saveToCloud, .traits]
            case .root:        return [.roots,                .saveToCloud, .traits]
            case .focus:       return [.roots,     .fetch,           .traits]
            case .parents:     return [                              .traits]
            case .children:    return [                              .traits]
            case .families:    return [            .fetch,           .traits]
            case .bookmarks:   return [.bookmarks, .fetch,    .saveToCloud, .traits]
            case .undelete:    return [.undelete,  .fetch,    .saveToCloud, .traits]
            case .fetchLost:   return [.fetchlost,            .saveToCloud,        ]
            case .emptyTrash:  return [.emptyTrash                          ]
            case .resumeCloud: return [.fetchNew,  .fetchAll, .saveToCloud         ]
            case .refetch:     return [            .fetchAll, .saveToCloud         ]
            case .newAppleID:  return operationIDs(from: .checkAvailability, to: .subscribe, skipping: [.readFile])
            case .startUp:     return operationIDs(from: .macAddress,        to: .here)
            case .finishUp:    return operationIDs(from: .fetchNew,          to: .subscribe)
            case .userTest:    return operationIDs(from: .observeUbiquity,   to: .fetchUserRecord)
            }
        }


        var localOperations : [ZOperationID] {
            var ids = [ZOperationID] ()

            for operation in operations {
                if operation.isLocal {
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


        func operationIDs(from: ZOperationID, to: ZOperationID, skipping: [ZOperationID] = []) -> [ZOperationID] {
            var operationIDs = [ZOperationID] ()

            for value in from.rawValue...to.rawValue {
                var add = true

                for skip in skipping {
                    if skip.rawValue == value {
                        add = false
                    }
                }

                if add {
                    operationIDs.append(ZOperationID(rawValue: value)!)
                }
            }

            return operationIDs
        }

    }


    var    currentBatches = [ZBatch] ()
    var   deferredBatches = [ZBatch] ()
    var currentDatabaseID : ZDatabaseID?
    var        totalCount :  Int { return currentBatches.count + deferredBatches.count }
    var            isLate : Bool { return lastOpStart != nil && lastOpStart!.timeIntervalSinceNow < -30.0 }


    // MARK:- API
    // MARK:-


    func       save(_ onCompletion: @escaping BooleanClosure) { batch(.saveToCloud,        onCompletion) }
    func       root(_ onCompletion: @escaping BooleanClosure) { batch(.root,        onCompletion) }
    func       sync(_ onCompletion: @escaping BooleanClosure) { batch(.sync,        onCompletion) }
    func      focus(_ onCompletion: @escaping BooleanClosure) { batch(.focus,       onCompletion) }
    func    startUp(_ onCompletion: @escaping BooleanClosure) { batch(.startUp,     onCompletion) }
    func    refetch(_ onCompletion: @escaping BooleanClosure) { batch(.refetch,     onCompletion) }
    func    parents(_ onCompletion: @escaping BooleanClosure) { batch(.parents,     onCompletion) }
    func   families(_ onCompletion: @escaping BooleanClosure) { batch(.families,    onCompletion) }
    func   finishUp(_ onCompletion: @escaping BooleanClosure) { batch(.finishUp,    onCompletion) }
    func   undelete(_ onCompletion: @escaping BooleanClosure) { batch(.undelete,    onCompletion) }
    func   userTest(_ onCompletion: @escaping BooleanClosure) { batch(.userTest,    onCompletion) }
    func  bookmarks(_ onCompletion: @escaping BooleanClosure) { batch(.bookmarks,   onCompletion) }
    func  fetchLost(_ onCompletion: @escaping BooleanClosure) { batch(.fetchLost,   onCompletion) }
    func emptyTrash(_ onCompletion: @escaping BooleanClosure) { batch(.emptyTrash,  onCompletion) }


    func  children(_ recursing: ZRecursionType = .all, _ iGoal: Int = Int.max, _ onCompletion: @escaping BooleanClosure) {
        gRecursionLogic       .type = recursing
        gRecursionLogic.targetLevel = iGoal

        batch(.children, onCompletion)
    }


    func processNextBatch() {

        // 1. execute next current batch
        // 2. called by superclass, for each completion operation. fire completions and recurse
        // 3. no more current batches,                            transfer deferred and recurse
        // 4. no more batches, nothing to process

        FOREGROUND(canBeDirect: true) {
            if  let      batch = self.currentBatches.first {
                let operations = batch.allowedOperations

                self.setupAndRun(operations) {                  // 1.
                    batch.fireCompletions()                     // 2.
                    self.maybeRemoveFirst()
                    self.processNextBatch()
                }
            } else if self.deferredBatches.count > 0 {
                self.transferDeferred()                         // 3.
                self.processNextBatch()
            }                                                   // 4.
        }
    }


    func batch(_ iID: ZBatchID, _ iCompletion: @escaping BooleanClosure) {
        if  iID.shouldIgnore {
            iCompletion(true) // true means no new data
        } else {
            let     current = getBatch(iID, from: currentBatches)
            let completions = [ZBatchCompletion(iCompletion)]
            let   startOver = currentBatches.count == 0

            // 1. is in deferral            -> add its completion to that deferred batch
            // 2. in neither                -> create new batch + append to current
            // 3. in current +  no deferred -> add its completion to that current batch
            // 4. in current + has deferred -> create new batch + append to deferred (other batches may change the state to what it expects)

            if  let deferred = getBatch(iID, from: deferredBatches) {
                deferred.completions.append(contentsOf: completions)    // 1.
            } else if current == nil {
                currentBatches .append(ZBatch(iID, completions))        // 2.
            } else if deferredBatches.count > 0 {
                deferredBatches.append(ZBatch(iID, completions))        // 3.
            } else {
                current?.completions.append(contentsOf: completions)    // 4.
            }

            if  startOver {
                processNextBatch()
            }
        }
    }


    // MARK:- internals
    // MARK:-


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

        ////////////////////////////////////////////////////////////
        // if current list is empty, transfer deferred to current //
        ////////////////////////////////////////////////////////////

        if  currentBatches.count == 0 && deferredBatches.count > 0 {
            currentBatches  = deferredBatches
            deferredBatches = []
        }
    }


    override func invokeMultiple(for operationID: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping BooleanClosure) {
        super.invokeMultiple(for: operationID, restoreToID: restoreToID) { iCompleted in

            //////////////////////////////////////////////////////////////////
            //     first, allow onboarding superclass to perform block      //
            // iCompleted will be false if it does not handle the operation //
            //////////////////////////////////////////////////////////////////

            if  iCompleted {
                onCompletion(true)
            } else {
                let              requiresActive = [.saveToCloud, .traits                ].contains(operationID)
                let               alwaysForBoth = [.here, .roots, .readFile].contains(operationID)
                let               forMineIDOnly = [.bookmarks, .subscribe, .unsubscribe].contains(operationID)
                let                      isMine = restoreToID == .mineID
                let               onlyCurrentID = (!gCloudAccountIsActive && !alwaysForBoth) || operationID == .completion
                let  databaseIDs: [ZDatabaseID] = forMineIDOnly ? [.mineID] : onlyCurrentID ? [restoreToID] : kAllDatabaseIDs
                let                      isNoop = !gCloudAccountIsActive && (requiresActive || (onlyCurrentID && isMine && operationID != .favorites))
                var invokeForIndex: IntClosure?                // declare closure first, so compiler will let it recurse
                invokeForIndex                  = { index in

                    /////////////////////////////////
                    // always called in foreground //
                    /////////////////////////////////

                    if  operationID == .completion || isNoop || index >= databaseIDs.count {
                        onCompletion(true)
                    } else {
                        self.currentDatabaseID = databaseIDs[index]      // if hung, it happened in this id

                        self.invokeOperation(for: operationID) { (iResult: Any?) in
                            self  .lastOpStart = nil

                            FOREGROUND(canBeDirect: true) {
                                let      error = iResult as? Error
                                let      value = iResult as? Int
                                let    isError = error != nil

                                if     isError || value == 0 {
                                    if isError {
                                        self.log(iResult)
                                    }

                                    invokeForIndex?(index + 1)         // recurse
                                }
                            }
                        }
                    }
                }

                invokeForIndex?(0)
                gControllers.signalFor(nil, regarding: .eInformation)
            }
        }
    }


    override func invokeOperation(for identifier: ZOperationID, cloudCallback: AnyClosure?) {
        onCloudResponse = cloudCallback     // for retry cloud in tools controller

        switch identifier {
        case .favorites:       gFavorites.setup(                                                                      cloudCallback)
        case .readFile:  gFiles                                    .readFile(into: currentDatabaseID!);                cloudCallback?(0)
        default: gRemoteStoresManager.cloudManager(for: currentDatabaseID!)?.invokeOperation(for: identifier, cloudCallback: cloudCallback)
        }
    }

}
