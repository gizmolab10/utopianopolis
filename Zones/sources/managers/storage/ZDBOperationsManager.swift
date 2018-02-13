//
//  ZDBOperationsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation


let gDBOperationsManager = ZDBOperationsManager()


class ZDBOperationsManager: ZOperationsManager {


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


    // MARK:- internals
    // MARK:-


    func     unHang()                                  {                                                                                                 onCloudResponse?(0) }
    func    startUp(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .onboard,  to: .read,                                                      onCompletion) }
    func continueUp(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .here,     to: .traits,                                                    onCompletion) }
    func   finishUp(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .save,     to: .subscribe,                                                 onCompletion) }
    func emptyTrash(_ onCompletion: @escaping Closure) { setupAndRun([.emptyTrash,                                                             .write]) { onCompletion() } }
    func  fetchLost(_ onCompletion: @escaping Closure) { setupAndRun([.fetchlost,                           .save, .children,                  .write]) { onCompletion() } }
    func   undelete(_ onCompletion: @escaping Closure) { setupAndRun([.undelete,  .fetch, .parents,         .save, .children,         .traits, .write]) { onCompletion() } }
    func      pSave(_ onCompletion: @escaping Closure) { setupAndRun([                                      .save,                             .write]) { onCompletion() } }
    func      pRoot(_ onCompletion: @escaping Closure) { setupAndRun([.root,                                .save, .children,         .traits, .write]) { onCompletion() } }
    func      pSync(_ onCompletion: @escaping Closure) { setupAndRun([            .fetch, .parents, .merge, .save, .children,         .traits, .write]) { onCompletion() } }
    func    pTravel(_ onCompletion: @escaping Closure) { setupAndRun([.root,              .parents,                .children, .fetch, .traits, .write]) { onCompletion() } }
    func   pParents(_ onCompletion: @escaping Closure) { setupAndRun([                    .parents,                                   .traits, .write]) { onCompletion() } }
    func  pFamilies(_ onCompletion: @escaping Closure) { setupAndRun([            .fetch, .parents,                .children,         .traits, .write]) { onCompletion() } }
    func pBookmarks(_ onCompletion: @escaping Closure) { setupAndRun([.bookmarks, .fetch,                   .save,                    .traits, .write]) { onCompletion() } }
    func  pChildren(_ onCompletion: @escaping Closure) { setupAndRun([                                             .children,         .traits, .write]) { onCompletion() } }


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
        case .save, .sync:                                               return  gSaveMode == .localOnly
        case .root, .travel, .parents, .children, .families, .bookmarks: return gFetchMode == .localOnly
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
        case .onboard:              gOnboardingManager.onboard        (                     cloudCallback!)
        case .root:                 remote            .establishRoot  (currentDatabaseID!,  cloudCallback)
        default: let cloudManager = remote            .cloudManagerFor(currentDatabaseID!)
        switch identifier { // inner switch
        case .cloud:                cloudManager.fetchCloudZones      (                     cloudCallback)
        case .bookmarks:            cloudManager.fetchBookmarks       (                     cloudCallback)
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
        case .merge:                cloudManager.merge                (                     cloudCallback)
        case .save:                 cloudManager.save                 (                     cloudCallback)
        default: break
            }               // inner switch
        }                   // outer switch

        return
    }


    override func performBlock(for operationID: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping Closure) {
        let   forCurrentdatabaseIDOnly = [.completion, .onboard, .here].contains(operationID)
        let              forMineIDOnly = [.bookmarks                  ].contains(operationID)
        let                     isMine = restoreToID == .mineID
        let              onlyCurrentID = !gHasPrivateDatabase || forCurrentdatabaseIDOnly
        let              dbIDs: ZDatabaseIDs = forMineIDOnly ? [.mineID] : onlyCurrentID ? [restoreToID] : [.mineID, .everyoneID]
        let                     isNoop = onlyCurrentID && isMine && !gHasPrivateDatabase
        var invokeDatabaseIDAt: IntClosure? = nil                // declare closure first, so compiler will let it recurse

        invokeDatabaseIDAt             = { index in

            /////////////////////////////////
            // always called in foreground //
            /////////////////////////////////

            if operationID == .completion || isNoop {
                self.queue.isSuspended = false

                onCompletion()
            } else if           index >= dbIDs.count {
                self.queue.isSuspended = false
            } else {
                self.currentDatabaseID = dbIDs[index]      // if hung, it happened in this id

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

                            invokeDatabaseIDAt?(index + 1)         // recurse
                        }
                    }
                }
            }
        }

        invokeDatabaseIDAt?(0)
        self.signalFor(nil, regarding: .information)
    }
}
