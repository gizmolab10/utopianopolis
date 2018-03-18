//
//  ZBatchManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation


let gBatchManager = ZBatchManager()


class ZBatchManager: ZOnboardingManager {


    enum ZBatchOperationID: Int {
        case save
        case root
        case sync
        case travel
        case parents
        case children
        case families
        case bookmarks
    }


    class ZBatchCompletion: NSObject {
        var completion : BooleanClosure?
        var   snapshot : ZSnapshot


        override init() {
            snapshot = gSelectionManager.snapshot
        }


        convenience init(_ iClosure: @escaping BooleanClosure) {
            self.init()

            completion = iClosure
        }


        func fire() {
            completion?(snapshot == gSelectionManager.snapshot)
        }
    }


    class ZBatch: NSObject {
        var completions : [ZBatchCompletion]
        var  identifier :  ZBatchOperationID

        init(_ iID: ZBatchOperationID, _ iCompletions: [ZBatchCompletion]) {
            completions = iCompletions
            identifier  = iID
        }


        func fireCompletions() {
            while let completion = completions.popLast() {
                completion.fire()
            }
        }
    }


    var        currentOps = [ZBatch] ()
    var       deferredOps = [ZBatch] ()
    var currentDatabaseID : ZDatabaseID? = nil
    var            isLate : Bool { return lastOpStart != nil && lastOpStart!.timeIntervalSinceNow < -30.0 }


    // MARK:- API
    // MARK:-


    func      save(_ onCompletion: @escaping BooleanClosure) { batch(.save,      onCompletion) }
    func      root(_ onCompletion: @escaping BooleanClosure) { batch(.root,      onCompletion) }
    func      sync(_ onCompletion: @escaping BooleanClosure) { batch(.sync,      onCompletion) }
    func    travel(_ onCompletion: @escaping BooleanClosure) { batch(.travel,    onCompletion) }
    func   parents(_ onCompletion: @escaping BooleanClosure) { batch(.parents,   onCompletion) }
    func  families(_ onCompletion: @escaping BooleanClosure) { batch(.families,  onCompletion) }
    func bookmarks(_ onCompletion: @escaping BooleanClosure) { batch(.bookmarks, onCompletion) }


    func  children(_ recursing: ZRecursionType = .all, _ iGoal: Int = Int.max, _ onCompletion: @escaping BooleanClosure) {
        gRecursionLogic       .type = recursing
        gRecursionLogic.targetLevel = iGoal

        batch(.children, onCompletion)
    }


    // MARK:- batches
    // MARK:-


    func isBatchID(_ iID: ZBatchOperationID, containedIn iList: [ZBatch]) -> Bool {
        return getBatch(iID, from: iList) != nil
    }


    func getBatch(_ iID: ZBatchOperationID, from iList: [ZBatch]) -> ZBatch? {
        for batch in iList {
            if  iID == batch.identifier {
                return batch
            }
        }

        return nil
    }


    func shouldIgnoreBatch(_ iID: ZBatchOperationID) -> Bool {
        switch iID {
        case .sync, .save: return false
        default:           return true
        }
    }


    func batch(_ iID: ZBatchOperationID, _ iCompletion: @escaping BooleanClosure) {
        if  shouldIgnoreBatch(iID) {
            iCompletion(true) // true means isSame
        } else {
            undefer()

            let   doClosure = currentOps.count == 0
            let completions = [ZBatchCompletion(iCompletion)]

            // if is in current batches -> move or append to end of deferred
            // else append to current batches

            if !isBatchID(iID, containedIn: currentOps) {
                currentOps.insert(ZBatch(iID, completions), at: 0)
            } else if let deferal = getBatch(iID, from: deferredOps) {
                deferal.completions.append(contentsOf: completions)
            } else {
                deferredOps.insert(ZBatch(iID, completions), at: 0)
            }

            if doClosure {
                var closure: Closure? = nil
                closure               = {
                    if  let     batch = self.currentOps.first {

                        self.currentOps.removeFirst()
                        self.invokeBatch(batch.identifier) {
                            batch.fireCompletions()
                            closure?()
                        }
                    } else if self.deferredOps.count > 0 {
                        self.undefer()
                        closure?()
                    }
                }

                closure?()
            }
        }
    }


    func undefer() {

        ////////////////////////////////////////////////////////////
        // if current list is empty, transfer deferred to current //
        ////////////////////////////////////////////////////////////

        if  currentOps.count == 0 && deferredOps.count > 0 {
            currentOps  = deferredOps
            deferredOps = []
        }
    }


    func invokeBatch(_ iID: ZBatchOperationID, _ onCompletion: @escaping Closure) {
        switch iID {
        case .save:      pSave      { onCompletion() }
        case .root:      pRoot      { onCompletion() }
        case .sync:      pSync      { onCompletion() }
        case .travel:    pTravel    { onCompletion() }
        case .parents:   pParents   { onCompletion() }
        case .children:  pChildren  { onCompletion() }
        case .families:  pFamilies  { onCompletion() }
        case .bookmarks: pBookmarks { onCompletion() }
        }
    }


    // MARK:- operations
    // MARK:-


    override func invoke(_ identifier: ZOperationID, cloudCallback: AnyClosure?) {
        let      remote = gRemoteStoresManager
        onCloudResponse = cloudCallback     // for retry cloud in tools controller

        switch identifier { // outer switch
        case .read:                 gFileManager      .read (for:      currentDatabaseID!); cloudCallback?(0)
        case .write:                gFileManager      .write(for:      currentDatabaseID!); cloudCallback?(0)
        default: let cloudManager = remote            .cloudManagerFor(currentDatabaseID!)
        switch identifier { // inner switch
        case .cloud:                cloudManager.fetchCloudZones      (                     cloudCallback)
        case .bookmarks:            cloudManager.fetchBookmarks       (                     cloudCallback)
        case .root:                 cloudManager.establishRoots       (                     cloudCallback)
        case .children:             cloudManager.fetchChildren        (                     cloudCallback)
        case .here:                 cloudManager.establishHere        (                     cloudCallback)
        case .parents:              cloudManager.fetchParents         (                     cloudCallback)
        case .refetch:              cloudManager.refetchZones         (                     cloudCallback)
        case .traits:               cloudManager.fetchTraits          (                     cloudCallback)
        case .unsubscribe:          cloudManager.unsubscribe          (                     cloudCallback)
        case .undelete:             cloudManager.undeleteAll          (                     cloudCallback)
        case .emptyTrash:           cloudManager.emptyTrash           (                     cloudCallback)
        case .fetch:                cloudManager.fetchZones           (                     cloudCallback)
        case .subscribe:            cloudManager.subscribe            (                     cloudCallback)
        case .fetchlost:            cloudManager.fetchLost            (                     cloudCallback)
        case .fetchNew:             cloudManager.fetchNew             (                     cloudCallback)
        case .fetchAll:             cloudManager.fetchAll             (                     cloudCallback)
        case .merge:                cloudManager.merge                (                     cloudCallback)
        case .found:                cloudManager.found                (                     cloudCallback)
        case .save:                 cloudManager.save                 (                     cloudCallback)
        default: break
            }               // inner switch
        }                   // outer switch

        return
    }


    override func performBlock(for operationID: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping BooleanClosure) {

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // onboarding is a superclass. allow it to perform block first. if it does not handle the operation id, it will return false //
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        super.performBlock(for: operationID, restoreToID: restoreToID) { iCompleted in
            if  iCompleted {
                onCompletion(true)
            } else {
                let    forCurrentdatabaseIDOnly = [.completion, .onboard, .here].contains(operationID)
                let               forMineIDOnly = [.bookmarks                  ].contains(operationID)
                let                      isMine = restoreToID == .mineID
                let               onlyCurrentID = !gHasPrivateDatabase || forCurrentdatabaseIDOnly
                let   databaseIDs: ZDatabaseIDs = forMineIDOnly ? [.mineID] : onlyCurrentID ? [restoreToID] : kAllDatabaseIDs
                let                      isNoop = onlyCurrentID && isMine && !gHasPrivateDatabase
                var invokeForIndex: IntClosure? = nil                // declare closure first, so compiler will let it recurse
                invokeForIndex                  = { index in

                    /////////////////////////////////
                    // always called in foreground //
                    /////////////////////////////////

                    if  operationID == .completion || isNoop || index >= databaseIDs.count {
                        onCompletion(true)
                    } else {
                        self.currentDatabaseID = databaseIDs[index]      // if hung, it happened in this id

                        self.invoke(operationID) { (iResult: Any?) in
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
                self.signalFor(nil, regarding: .information)
            }
        }
    }
}
