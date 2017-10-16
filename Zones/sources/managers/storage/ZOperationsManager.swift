//
//  ZOperationsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation


enum ZOperationID: Int {
    case authenticate
    case cloud
    case roots
    case file
    case manifest
    case here
    case children
    case fetch
    case parent
    case save // zones, manifests, favorites
    case unsubscribe
    case subscribe

    /////////////////////////////////////////////////////////////////////
    // the following do not participate in startup, finish up, or sync //
    /////////////////////////////////////////////////////////////////////

    case emptyTrash
    case completion
    case bookmarks
    case undelete
    case create
    case merge
    case trash
    case none
}


class ZOperationsManager: NSObject {


    var onCloudResponse :   AnyClosure? = nil
    var     currentMode : ZStorageMode? = nil
    var     lastOpStart :         Date? = nil
    var          isLate :         Bool  { return lastOpStart != nil && lastOpStart!.timeIntervalSinceNow < -30.0 }
    var       currentOp = ZOperationID.none
    var           queue = OperationQueue()
    var           debug = false


    // MARK:- API
    // MARK:-


    func    startUp(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .authenticate, to: .manifest,                    onCompletion) }
    func continueUp(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .here,         to: .parent,                      onCompletion) }
    func   finishUp(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .save,         to: .subscribe,                   onCompletion) }
    func     travel(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .here,         to: .save,                        onCompletion) }
    func       save(_ onCompletion: @escaping Closure) { setupAndRun([.create,                    .merge, .save           ]) { onCompletion() } }
    func      roots(_ onCompletion: @escaping Closure) { setupAndRun([.roots,                             .save, .children]) { onCompletion() } }
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


    private func invoke(_ identifier: ZOperationID, _ mode: ZStorageMode, _ logic: ZRecursionLogic? = nil, cloudCallback: AnyClosure?) {
        if  mode           != .favoritesMode || identifier == .here {
            let      remote = gRemoteStoresManager
            onCloudResponse = cloudCallback     // for retry cloud in tools controller
            currentMode     = mode              // if hung, it happened in this mode

            reportOp(identifier, mode, 0)

            switch identifier { // outer switch
            case .file:                 gFileManager.restore  (from:          mode);    cloudCallback?(0)
            case .here:                 remote               .establishHere  (mode,     cloudCallback)
            case .roots:                remote               .establishRoot  (mode,     cloudCallback)
            default: let cloudManager = remote               .cloudManagerFor(mode)
            switch identifier { // inner switch
            case .authenticate: remote.authenticate                          (          cloudCallback)
            case .cloud:        cloudManager.fetchCloudZones                 (          cloudCallback)
            case .bookmarks:    cloudManager.fetchBookmarks                  (          cloudCallback)
            case .manifest:     cloudManager.fetchManifest                   (          cloudCallback)
            case .children:     cloudManager.fetchChildren                   (logic,    cloudCallback)
            case .parent:       cloudManager.fetchParents                    (          cloudCallback)
            case .unsubscribe:  cloudManager.unsubscribe                     (          cloudCallback)
            case .undelete:     cloudManager.undeleteAll                     (          cloudCallback)
            case .emptyTrash:   cloudManager.emptyTrash                      (          cloudCallback)
            case .trash:        cloudManager.fetchTrash                      (          cloudCallback)
            case .subscribe:    cloudManager.subscribe                       (          cloudCallback)
            case .create:       cloudManager.create                          (          cloudCallback)
            case .fetch:        cloudManager.fetch                           (          cloudCallback)
            case .merge:        cloudManager.merge                           (          cloudCallback)
            case .save:         cloudManager.save                            (          cloudCallback)
            default: break
                } // inner switch
            } // outer switch

            return
        }
    }


    private func setupAndRunUnsafe(_ operationIDs: [ZOperationID], logic: ZRecursionLogic?, onCompletion: @escaping Closure) {
        if gIsLate {
            onCompletion()
        }

        queue.isSuspended = true
        let         saved = gStorageMode
        let        isMine = [.mineMode].contains(saved)

        for operationID in operationIDs + [.completion] {
            let                     blockOperation = BlockOperation {
                self.FOREGROUND {
                    self                .currentOp = operationID        // if hung, it happened inside this op
                    var  invokeModeAt: IntClosure? = nil                // declare closure first, so compiler will let it recurse
                    let              skipFavorites = operationID != .here
                    let                       full = [.unsubscribe, .subscribe, .manifest, .children, .parent, .fetch, .cloud, .roots, .here].contains(operationID)
                    let  forCurrentStorageModeOnly = [.file, .completion, .authenticate                                                     ].contains(operationID)
                    let         cloudModes: ZModes = [.mineMode, .everyoneMode]
                    let              modes: ZModes = !full && (forCurrentStorageModeOnly || isMine) ? [saved] : skipFavorites ? cloudModes : cloudModes + [.favoritesMode]

                    invokeModeAt                   = { index in

                        /////////////////////////////////
                        // always called in foreground //
                        /////////////////////////////////

                        if operationID == .completion {
                            onCompletion()
                        } else if      index < modes.count {
                            let         mode = modes[index]
                            self.lastOpStart = Date()

                            self.invoke(operationID, mode, logic) { (iResult: Any?) in
                                self.lastOpStart = nil

                                self.FOREGROUND(canBeDirect: true) {
                                    let      error = iResult as? Error
                                    let      value = iResult as? Int
                                    let    isError = error != nil

                                    if     isError || value == 0 {
                                        if isError {
                                            self.report(iResult)
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

            addOperation(blockOperation)
        }

        queue.isSuspended = false
    }


    private func setupAndRun(_ operationIDs: [ZOperationID], logic: ZRecursionLogic? = nil, onCompletion: @escaping Closure) {
        FOREGROUND(canBeDirect: true) {
            self.setupAndRunUnsafe(operationIDs, logic: logic, onCompletion: onCompletion)
        }
    }


    private func setupAndRunOps(from: ZOperationID, to: ZOperationID, _ onCompletion: @escaping Closure) {
        var operationIDs = [ZOperationID] ()

        for sync in from.rawValue...to.rawValue {
            operationIDs.append(ZOperationID(rawValue: sync)!)
        }

        setupAndRun(operationIDs) { onCompletion() }
    }


    private func addOperation(_ op: BlockOperation) {
        if let prior = queue.operations.last {
            op.addDependency(prior)
        } else {
            queue.qualityOfService            = .background
            queue.maxConcurrentOperationCount = 1
        }

        queue.addOperation(op)
    }


    private func reportOp(_ identifier: ZOperationID, _ mode: ZStorageMode, _ iCount: Int) {
        if  debug {
            let   count = iCount <= 0 ? "" : "\(iCount)"
            var message = "\(String(describing: identifier)) \(count)"

            message.appendSpacesToLength(gLogTabStop - 2)
            report("\(message)• \(mode)")
        }
    }
}
