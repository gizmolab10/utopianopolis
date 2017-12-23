//
//  ZDBOperationsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation


let gDBOperationsManager = ZDBOperationsManager()


typealias stringKeyedItems = [String: Any]


let r = "recursion type"
let c = "on completion"
let g = "goal"


class ZDBOperationsManager: ZOperationsManager {


    enum ZBatchOperationID: Int {
        case save
        case root
        case sync
        case travel
        case delete
        case parents
        case children
        case families
        case bookmarks
    }


    class ZBatch: NSObject {
        var identifier: ZBatchOperationID
        var  itemsList: [stringKeyedItems]

        init(_ iID: ZBatchOperationID, _ iItemsList: [stringKeyedItems]) {
            itemsList  = iItemsList
            identifier = iID
        }
    }


    var  currentOps = [ZBatch] ()
    var deferredOps = [ZBatch] ()
    var      isLate : Bool { return lastOpStart != nil && lastOpStart!.timeIntervalSinceNow < -30.0 }
    var currentMode : ZStorageMode? = nil


    // MARK:- API
    // MARK:-


    func      save(_ onCompletion: @escaping Closure) { batch(.save,      [c : onCompletion]) }
    func      root(_ onCompletion: @escaping Closure) { batch(.root,      [c : onCompletion]) }
    func      sync(_ onCompletion: @escaping Closure) { batch(.sync,      [c : onCompletion]) }
    func    travel(_ onCompletion: @escaping Closure) { batch(.travel,    [c : onCompletion]) }
    func    delete(_ onCompletion: @escaping Closure) { batch(.delete,    [c : onCompletion]) }
    func   parents(_ onCompletion: @escaping Closure) { batch(.parents,   [c : onCompletion]) }
    func  families(_ onCompletion: @escaping Closure) { batch(.families,  [c : onCompletion]) }
    func bookmarks(_ onCompletion: @escaping Closure) { batch(.bookmarks, [c : onCompletion]) }


    func  children(_ recursing: ZRecursionType = .restore, _ iGoal: Int? = nil, _ onCompletion: @escaping Closure) {
        var items = stringKeyedItems()
        items [c] = onCompletion
        items [r] = recursing
        items [g] = iGoal

        batch(.children, items)
    }


    // MARK:- internals
    // MARK:-


    func     unHang()                                  {                                                                                                    onCloudResponse?(0) }
    func    startUp(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .onboard, to: .manifest,                                                      onCompletion) }
    func continueUp(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .here,    to: .traits,                                                        onCompletion) }
    func   finishUp(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .save,    to: .subscribe,                                                     onCompletion) }
    func emptyTrash(_ onCompletion: @escaping Closure) { setupAndRun([.emptyTrash,                                                            .remember]) { onCompletion() } }
    func fetchTrash(_ onCompletion: @escaping Closure) { setupAndRun([.trash,                              .save, .children,         .traits, .remember]) { onCompletion() } }
    func   undelete(_ onCompletion: @escaping Closure) { setupAndRun([.undelete, .fetch, .parents,         .save, .children,         .traits, .remember]) { onCompletion() } }
    func      pSave(_ onCompletion: @escaping Closure) { setupAndRun([                                     .save                                       ]) { onCompletion() } }
    func      pRoot(_ onCompletion: @escaping Closure) { setupAndRun([.root,                               .save, .children,         .traits, .remember]) { onCompletion() } }
    func      pSync(_ onCompletion: @escaping Closure) { setupAndRun([.delete,   .fetch, .parents, .merge, .save, .children,         .traits, .remember]) { onCompletion() } }
    func    pTravel(_ onCompletion: @escaping Closure) { setupAndRun([.root, .manifest,  .parents,                .children, .fetch, .traits, .remember]) { onCompletion() } }
    func   pParents(_ onCompletion: @escaping Closure) { setupAndRun([                   .parents,                                   .traits, .remember]) { onCompletion() } }
    func  pFamilies(_ onCompletion: @escaping Closure) { setupAndRun([                   .parents,                .children,         .traits, .remember]) { onCompletion() } }
    func    pDelete(_ onCompletion: @escaping Closure) { setupAndRun([.bookmarks, .delete,                                                    .remember]) { onCompletion() } }
    func pBookmarks(_ onCompletion: @escaping Closure) { setupAndRun([.bookmarks,                                                    .traits, .remember]) { onCompletion() } }


    func pChildren(_ recursing: ZRecursionType, _ iGoal: Int?, _ onCompletion: @escaping Closure) {
        let logic = ZRecursionLogic(recursing,    iGoal)

        setupAndRun([.manifest, .children], logic: logic) { onCompletion() }
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


    func batch(_ iID: ZBatchOperationID, _ items: stringKeyedItems) {
        undefer()

        let doClosure = currentOps.count == 0

        // if is in current batches -> move or append to end of deferred
        // else append to current batches

        if !isBatchID(iID, containedIn: currentOps) {
            currentOps.append(ZBatch(iID, [items]))
        } else if let deferal = getBatch(iID, from: deferredOps) {
            deferal.itemsList += [items]
        } else {
            deferredOps.append(ZBatch(iID, [items]))
        }

        if doClosure {
            var closure: Closure? = nil
            closure               = {
                if  let     batch = self.currentOps.first {
                    var      list = batch.itemsList

                    self.currentOps.remove(at: 0)

                    if  var items = list.first {
                        list.remove(at: 0)

                        self.invokeBatch(batch.identifier, items) {
                            while list.count > 0 {
                                items      = list.first!
                                let finish = items[c] as? Closure

                                list.remove(at: 0)
                                finish?()
                            }

                            closure?()
                        }
                    } else {
                        self.undefer()
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


    func undefer() {

        ////////////////////////////////////////////////////////////
        // if current list is empty, transfer deferred to current //
        ////////////////////////////////////////////////////////////

        if  currentOps.count == 0 && deferredOps.count > 0 {
            currentOps  = deferredOps
            deferredOps = []
        }
    }


    func invokeBatch(_ iID: ZBatchOperationID, _ items: stringKeyedItems, _ iClosure: @escaping Closure) {
        if  let onCompletion = items[c] as? Closure {
            switch iID {
            case .save:      pSave        { onCompletion(); iClosure() }
            case .root:      pRoot        { onCompletion(); iClosure() }
            case .sync:      pSync        { onCompletion(); iClosure() }
            case .travel:    pTravel      { onCompletion(); iClosure() }
            case .delete:    pDelete      { onCompletion(); iClosure() }
            case .parents:   pParents     { onCompletion(); iClosure() }
            case .families:  pFamilies    { onCompletion(); iClosure() }
            case .bookmarks: pBookmarks   { onCompletion(); iClosure() }
            case .children:
                if  let type = items[r] as? ZRecursionType {
                    let goal = items[g] as? Int

                    pChildren(type, goal) { onCompletion(); iClosure() }
                }
            }
        }
    }


    // MARK:- operations
    // MARK:-


    override func invoke(_ identifier: ZOperationID, _ logic: ZRecursionLogic? = nil, cloudCallback: AnyClosure?) {
        let      remote = gRemoteStoresManager
        onCloudResponse = cloudCallback     // for retry cloud in tools controller

        switch identifier { // outer switch
        case .file:                 gFileManager         .restore  (from: currentMode!); cloudCallback?(0)
        case .onboard:              gOnboardingManager   .onboard        (               cloudCallback!)
        case .here:                 remote               .establishHere  (currentMode!,  cloudCallback)
        case .root:                 remote               .establishRoot  (currentMode!,  cloudCallback)
        default: let cloudManager = remote               .cloudManagerFor(currentMode!)
        switch identifier { // inner switch
        case .cloud:                cloudManager.fetchCloudZones         (               cloudCallback)
        case .bookmarks:            cloudManager.fetchBookmarks          (               cloudCallback)
        case .manifest:             cloudManager.fetchManifest           (               cloudCallback)
        case .children:             cloudManager.fetchChildren           (logic,         cloudCallback)
        case .parents:              cloudManager.fetchParents            (               cloudCallback)
        case .traits:               cloudManager.fetchTraits             (               cloudCallback)
        case .unsubscribe:          cloudManager.unsubscribe             (               cloudCallback)
        case .undelete:             cloudManager.undeleteAll             (               cloudCallback)
        case .emptyTrash:           cloudManager.emptyTrash              (               cloudCallback)
        case .trash:                cloudManager.fetchTrash              (               cloudCallback)
        case .subscribe:            cloudManager.subscribe               (               cloudCallback)
        case .refetch:              cloudManager.refetch                 (               cloudCallback)
        case .remember:             cloudManager.remember                (               cloudCallback)
        case .delete:               cloudManager.delete                  (               cloudCallback)
        case .fetch:                cloudManager.fetch                   (               cloudCallback)
        case .merge:                cloudManager.merge                   (               cloudCallback)
        case .save:                 cloudManager.save                    (               cloudCallback)
        default: break
            }               // inner switch
        }                   // outer switch

        return
    }


    override func performBlock(for operationID: ZOperationID, with logic: ZRecursionLogic? = nil, restoreToMode: ZStorageMode, _ onCompletion: @escaping Closure) {
        let  forCurrentStorageModeOnly = [.completion, .onboard ].contains(operationID)
        let            forMineModeOnly = [.bookmarks            ].contains(operationID)
        let                     isMine = restoreToMode == .mineMode
        let            onlyCurrentMode = !gHasPrivateDatabase || forCurrentStorageModeOnly
        let              modes: ZModes = forMineModeOnly ? [.mineMode] : onlyCurrentMode ? [restoreToMode] : [.mineMode, .everyoneMode]
        let                     isNoop = onlyCurrentMode && isMine && !gHasPrivateDatabase
        var  invokeModeAt: IntClosure? = nil                // declare closure first, so compiler will let it recurse

        invokeModeAt                   = { index in

            /////////////////////////////////
            // always called in foreground //
            /////////////////////////////////

            if operationID == .completion || isNoop {
                self.queue.isSuspended = false

                onCompletion()
            } else if           index >= modes.count {
                self.queue.isSuspended = false
            } else {
                self      .currentMode = modes[index]      // if hung, it happened in this mode

                self.invoke(operationID, logic) { (iResult: Any?) in
                    self  .lastOpStart = nil

                    FOREGROUND(canBeDirect: true) {
                        let      error = iResult as? Error
                        let      value = iResult as? Int
                        let    isError = error != nil

                        if     isError || value == 0 {
                            if isError {
                                self.log(iResult)
                            }

                            invokeModeAt?(index + 1)         // recurse
                        }
                    }
                }
            }
        }

        invokeModeAt?(0)
    }
}
