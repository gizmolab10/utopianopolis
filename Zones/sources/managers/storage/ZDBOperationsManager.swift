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


    func     unHang()                                  {                                                                       onCloudResponse?(0) }
    func    startUp(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .clear,        to: .manifest,                    onCompletion) }
    func continueUp(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .here,         to: .parent,                      onCompletion) }
    func   finishUp(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .save,         to: .subscribe,                   onCompletion) }
    func     travel(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .root,         to: .save,                        onCompletion) }
    func       save(_ onCompletion: @escaping Closure) { setupAndRun([.create,                    .merge, .save           ]) { onCompletion() } }
    func       root(_ onCompletion: @escaping Closure) { setupAndRun([.root,                              .save, .children]) { onCompletion() } }
    func fetchTrash(_ onCompletion: @escaping Closure) { setupAndRun([.trash,                             .save, .children]) { onCompletion() } }
    func       sync(_ onCompletion: @escaping Closure) { setupAndRun([.create,   .fetch, .parent, .merge, .save, .children]) { onCompletion() } }
    func   undelete(_ onCompletion: @escaping Closure) { setupAndRun([.undelete, .fetch, .parent,         .save, .children]) { onCompletion() } }
    func   families(_ onCompletion: @escaping Closure) { setupAndRun([                   .parent,                .children]) { onCompletion() } }
    func     parent(_ onCompletion: @escaping Closure) { setupAndRun([                   .parent                          ]) { onCompletion() } }
    func emptyTrash(_ onCompletion: @escaping Closure) { setupAndRun([.emptyTrash                                         ]) { onCompletion() } }
    func  bookmarks(_ onCompletion: @escaping Closure) { setupAndRun([.bookmarks                                          ]) { onCompletion() } }


    func children(_ recursing: ZRecursionType, _ iGoal: Int? = nil, onCompletion: @escaping Closure) {
        let logic = ZRecursionLogic(recursing,   iGoal)

        setupAndRun([.manifest, .children], logic: logic) { onCompletion() }
    }


    // MARK:- internals
    // MARK:-


    override func invoke(_ identifier: ZOperationID, _ logic: ZRecursionLogic? = nil, cloudCallback: AnyClosure?) {
        let      remote = gRemoteStoresManager
        onCloudResponse = cloudCallback     // for retry cloud in tools controller

        switch identifier {      // outer switch
        case .file:                 gFileManager         .restore  (from: currentMode!); cloudCallback?(0)
        case .onboard:              gOnboardingManager   .onboard        (               cloudCallback!)
        case .here:                 remote               .establishHere  (currentMode!,  cloudCallback)
        case .root:                 remote               .establishRoot  (currentMode!,  cloudCallback)
        case .clear:                remote               .clear          ();             cloudCallback?(0)
        default: let cloudManager = remote               .cloudManagerFor(currentMode!)
        switch identifier {      // inner switch
        case .cloud:                cloudManager.fetchCloudZones         (               cloudCallback)
        case .bookmarks:            cloudManager.fetchBookmarks          (               cloudCallback)
        case .manifest:             cloudManager.fetchManifest           (               cloudCallback)
        case .children:             cloudManager.fetchChildren           (logic,         cloudCallback)
        case .parent:               cloudManager.fetchParents            (               cloudCallback)
        case .unsubscribe:          cloudManager.unsubscribe             (               cloudCallback)
        case .undelete:             cloudManager.undeleteAll             (               cloudCallback)
        case .emptyTrash:           cloudManager.emptyTrash              (               cloudCallback)
        case .trash:                cloudManager.fetchTrash              (               cloudCallback)
        case .subscribe:            cloudManager.subscribe               (               cloudCallback)
        case .create:               cloudManager.create                  (               cloudCallback)
        case .fetch:                cloudManager.fetch                   (               cloudCallback)
        case .merge:                cloudManager.merge                   (               cloudCallback)
        case .save:                 cloudManager.save                    (               cloudCallback)
        default: break
            } // inner switch
        } // outer switch

        return
    }


    override func performBlock(on operationID: ZOperationID, with logic: ZRecursionLogic? = nil, restoreToMode: ZStorageMode, _ onCompletion: @escaping Closure) {
        let                     isMine = [.mineMode].contains(restoreToMode)
        var  invokeModeAt: IntClosure? = nil                // declare closure first, so compiler will let it recurse
        let                       full = [.unsubscribe, .subscribe, .children, .parent, .fetch, .cloud, .clear, .root, .here].contains(operationID)
        let  forCurrentStorageModeOnly = [.file, .completion, .onboard                                                      ].contains(operationID)
        let            forMineModeOnly = [.bookmarks, .manifest                                                             ].contains(operationID)
        let            onlyCurrentMode = !gHasPrivateDatabase || (!full && (forCurrentStorageModeOnly || isMine))
        let              modes: ZModes = forMineModeOnly ? [.mineMode] : onlyCurrentMode ? [restoreToMode] : [.mineMode, .everyoneMode]
        let                     isNoop = onlyCurrentMode && isMine && !gHasPrivateDatabase

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
                self      .lastOpStart = Date()

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
