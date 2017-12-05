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


    var currentMode : ZStorageMode? = nil
    var      isLate :         Bool  { return lastOpStart != nil && lastOpStart!.timeIntervalSinceNow < -30.0 }


    // MARK:- API
    // MARK:-


    func     unHang()                                  {                                                                                                              onCloudResponse?(0) }
    func    startUp(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .onboard, to: .manifest,                                                                onCompletion) }
    func continueUp(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .here,    to: .traits,                                                                  onCompletion) }
    func   finishUp(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .save,    to: .subscribe,                                                               onCompletion) }
    func       save(_ onCompletion: @escaping Closure) { setupAndRun([                                     .save                                                 ]) { onCompletion() } }
    func       root(_ onCompletion: @escaping Closure) { setupAndRun([.root,                               .save, .children,                   .traits, .remember]) { onCompletion() } }
    func     travel(_ onCompletion: @escaping Closure) { setupAndRun([.root, .manifest,                           .children, .parents, .fetch, .traits, .remember]) { onCompletion() } }
    func fetchTrash(_ onCompletion: @escaping Closure) { setupAndRun([.trash,                              .save, .children,                   .traits, .remember]) { onCompletion() } }
    func       sync(_ onCompletion: @escaping Closure) { setupAndRun([           .fetch, .parents, .merge, .save, .children,                   .traits, .remember]) { onCompletion() } }
    func   undelete(_ onCompletion: @escaping Closure) { setupAndRun([.undelete, .fetch, .parents,         .save, .children,                   .traits, .remember]) { onCompletion() } }
    func   families(_ onCompletion: @escaping Closure) { setupAndRun([                   .parents,                .children,                   .traits, .remember]) { onCompletion() } }
    func    parents(_ onCompletion: @escaping Closure) { setupAndRun([                   .parents                                                                ]) { onCompletion() } }
    func emptyTrash(_ onCompletion: @escaping Closure) { setupAndRun([.emptyTrash                                                                                ]) { onCompletion() } }
    func  bookmarks(_ onCompletion: @escaping Closure) { setupAndRun([.bookmarks                                                                                 ]) { onCompletion() } }


    func children(_ recursing: ZRecursionType, _ iGoal: Int? = nil, onCompletion: @escaping Closure) {
        let logic = ZRecursionLogic(recursing,   iGoal)

        setupAndRun([.manifest, .children], logic: logic) { onCompletion() }
    }


    // MARK:- internals
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
