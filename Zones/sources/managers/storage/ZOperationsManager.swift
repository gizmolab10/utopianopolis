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
    case manifest
    case file
    case here
    case fetch
    case toRoot
    case children
    case save // zones, manifests, favorites
    case unsubscribe
    case subscribe

    /////////////////////////////////////////////////////////////////////
    // the following do not participate in startup, finish up, or sync //
    /////////////////////////////////////////////////////////////////////

    case emptyTrash
    case available
    case bookmarks
    case undelete
    case create
    case parent
    case merge
    case trash
    case none
}


class ZOperationsManager: NSObject {


    var   cloudCallback :    AnyClosure? = nil
    var     lastOpStart :          Date? = nil
    var     currentMode :  ZStorageMode? = nil
    var       currentOp =  ZOperationID.none
    var      waitingOps = [ZOperationID  : BlockOperation] ()
    var completionStack =                        [Closure] ()
    var           debug = false
    var           queue = OperationQueue()


    // MARK:- API
    // MARK:-


    var isLate: Bool {
        return lastOpStart != nil && lastOpStart!.timeIntervalSinceNow < -30.0
    }


    func startUp(_ onCompletion: @escaping Closure) {
        var operationIDs = [ZOperationID] ()

        for sync in ZOperationID.authenticate.rawValue...ZOperationID.children.rawValue {
            operationIDs.append(ZOperationID(rawValue: sync)!)
        }

        setupAndRun(operationIDs) { onCompletion() }
    }
    

    func finishUp(_ onCompletion: @escaping Closure) {
        var operationIDs = [ZOperationID] ()

        for sync in ZOperationID.save.rawValue...ZOperationID.subscribe.rawValue {
            operationIDs.append(ZOperationID(rawValue: sync)!)
        }

        setupAndRun(operationIDs) { onCompletion() }
    }


    func travel(_ onCompletion: @escaping Closure) {
        var operationIDs = [ZOperationID] ()

        for sync in ZOperationID.here.rawValue...ZOperationID.save.rawValue {
            operationIDs.append(ZOperationID(rawValue: sync)!)
        }

        setupAndRun(operationIDs) { onCompletion() }
    }


    func       sync(_ onCompletion: @escaping Closure) { setupAndRun([.create,   .fetch, .parent, .merge, .save, .children]) { onCompletion() } }
    func       save(_ onCompletion: @escaping Closure) { setupAndRun([.create,                    .merge, .save           ]) { onCompletion() } }
    func      roots(_ onCompletion: @escaping Closure) { setupAndRun([.roots,                             .save, .children]) { onCompletion() } }
    func     parent(_ onCompletion: @escaping Closure) { setupAndRun([                   .parent                          ]) { onCompletion() } }
    func   families(_ onCompletion: @escaping Closure) { setupAndRun([                   .parent,                .children]) { onCompletion() } }
    func   undelete(_ onCompletion: @escaping Closure) { setupAndRun([.undelete, .fetch, .parent,         .save, .children]) { onCompletion() } }
    func fetchTrash(_ onCompletion: @escaping Closure) { setupAndRun([.trash,                             .save, .children]) { onCompletion() } }
    func emptyTrash(_ onCompletion: @escaping Closure) { setupAndRun([.emptyTrash                                         ]) { onCompletion() } }
    func  bookmarks(_ onCompletion: @escaping Closure) { setupAndRun([.bookmarks                                          ]) { onCompletion() } }


    func children(_ recursing: ZRecursionType, _ iRecursiveGoal: Int? = nil, onCompletion: @escaping Closure) {
        let logic = ZRecursionLogic(recursing, iRecursiveGoal)

        setupAndRun([.manifest, .children], logic: logic) { onCompletion() }
    }


    // MARK:- internals
    // MARK:-


    func invoke(_ identifier: ZOperationID, _ mode: ZStorageMode, _ logic: ZRecursionLogic? = nil) {
        if identifier == .available {
            FOREGROUND {
                self.becomeAvailable()
            }
        } else if mode != .favoritesMode || identifier == .here {
            let  remote = gRemoteStoresManager
            currentMode = mode             // if hung, it happened in this mode
            lastOpStart = Date()

            reportOp(identifier, mode, 0)

            switch identifier {
            case .file:                 gFileManager.restore  (from:          mode);    cloudCallback?(0)
            case .here:                 remote               .establishHere  (mode,     cloudCallback)
            case .roots:                remote               .establishRoot  (mode,     cloudCallback)
            default: let cloudManager = remote               .cloudManagerFor(mode)
            switch identifier {
            case .authenticate: remote.authenticate                      (          cloudCallback)
            case .cloud:        cloudManager.fetchCloudZones             (          cloudCallback)
            case .manifest:     cloudManager.fetchManifest               (          cloudCallback)
            case .children:     cloudManager.fetchChildren               (logic,    cloudCallback)
            case .parent:       cloudManager.fetchParents                (.restore, cloudCallback)
            case .toRoot:       cloudManager.fetchParents                (.all,     cloudCallback)
            case .unsubscribe:  cloudManager.unsubscribe                 (          cloudCallback)
            case .undelete:     cloudManager.undeleteAll                 (          cloudCallback)
            case .emptyTrash:   cloudManager.emptyTrash                  (          cloudCallback)
            case .trash:        cloudManager.fetchTrash                  (          cloudCallback)
            case .subscribe:    cloudManager.subscribe                   (          cloudCallback)
            case .bookmarks:    cloudManager.bookmarks                   (          cloudCallback)
            case .create:       cloudManager.create                      (          cloudCallback)
            case .fetch:        cloudManager.fetch                       (          cloudCallback)
            case .merge:        cloudManager.merge                       (          cloudCallback)
            case .save:         cloudManager.save                        (          cloudCallback)
            default: break
                }
            }

            return
        }
    }


    private func setupAndRun(_ operationIDs: [ZOperationID], logic: ZRecursionLogic? = nil, onCompletion: @escaping Closure) {
        FOREGROUND {
            self.setupAndRunUnsafe(operationIDs, logic: logic, onCompletion: onCompletion)
        }
    }


    private func setupAndRunUnsafe(_ operationIDs: [ZOperationID], logic: ZRecursionLogic? = nil, onCompletion: @escaping Closure) {
        if gIsLate {
            onCompletion()
        }

        let count = completionStack.count

        if  count > 0 {         // if already pre-queued
            if  lastOpStart != nil || waitingOps.count > 0 {
                columnarReport("   STACK", "\(count)")
                completionStack.append {        // push another onto stack
                    self.FOREGROUND {
                        self.fireCompletion()
                        self.setupAndRun(operationIDs, logic: logic, onCompletion: onCompletion)
                    }
                }
            } else if waitingOps.count == 0 {
                becomeAvailable()
            } else {
                cloudCallback?(0)
            }
        } else {
            completionStack.append(onCompletion)

            queue.isSuspended = true
            let         saved = gStorageMode
            let        isMine = [.mineMode].contains(saved)

            for operationID in operationIDs + [.available] {
                let                    blockOperation = BlockOperation {
                    self.FOREGROUND {
                        self                .currentOp = operationID             // if hung, it happened inside this op
                        var  invokeModeAt: IntClosure? = nil                // declare closure first, so compiler will let it recurse
                        let              skipFavorites = operationID != .here
                        let                       full = [.unsubscribe, .subscribe, .manifest, .toRoot, .cloud, .roots, .here].contains(operationID)
                        let  forCurrentStorageModeOnly = [.file, .available, .parent, .children, .authenticate               ].contains(operationID)
                        let         cloudModes: ZModes = [.mineMode, .everyoneMode]
                        let              modes: ZModes = !full && (forCurrentStorageModeOnly || isMine) ? [saved] : skipFavorites ? cloudModes : cloudModes + [.favoritesMode]

                        invokeModeAt                   = { index in

                            /////////////////////////////////
                            // always called in foreground //
                            /////////////////////////////////

                            if index >= modes.count {
                                self.killOperation(for: operationID)
                            } else {
                                let               mode = modes[index]
                                self    .cloudCallback = { (iResult: Any?) in
                                    self.FOREGROUND {
                                        let      error = iResult as? Error
                                        let      value = iResult as? Int
                                        let    isError = error != nil

                                        if     isError || value == 0 {
                                            if isError {
                                                self.report(iResult)
                                            }

                                            self.lastOpStart = nil

                                            invokeModeAt?(index + 1)         // recurse
                                        }
                                    }
                                }

                                self.invoke(operationID, mode, logic)
                            }
                        }

                        invokeModeAt?(0)
                    }
                }

                waitingOps[operationID] = blockOperation

                addOperation(blockOperation)
            }

            queue.isSuspended = false
        }
    }


    func unHang() {
        FOREGROUND {
            if let response = self.cloudCallback {
                response(0)
            } else if self.currentOp != .available || self.waitingOps.count > 0 {
                self.becomeAvailable()
            } else {
                self.fireCompletion()
            }
        }
    }


    func becomeAvailable() {
        gRemoteStoresManager.cancel()
        queue.cancelAllOperations()
        reportWaiters()
        unwaitAll()

        cloudCallback  = nil
        currentMode    = nil
        currentOp      = .available
        queue          = OperationQueue()

        fireCompletion()
    }


    func fireCompletion() {
        if  completionStack.count > 0 {
            completionStack.remove(at: 0)()
        }
    }


    func unwaitAll() {
        for identifier in waitingOps.keys {
            killOperation(for: identifier)
        }
    }


    func killOperation(for identifier: ZOperationID) {
        var operation = waitingOps[identifier]

        if  operation == nil {
            operation = queue.operations.first as? BlockOperation
        } else {
            waitingOps[identifier] = nil
        }

        operation?.kill()
    }


    func addOperation(_ op: BlockOperation) {
        if let prior = queue.operations.last {
            op.addDependency(prior)
        } else {
            queue.qualityOfService            = .background
            queue.maxConcurrentOperationCount = 1
        }

        queue.addOperation(op)
    }


    func reportWaiters() {
        let       keys = Array(waitingOps.keys)

        if  keys.count > 1 {
            let string = keys.apply() { key -> (String) in
                return "\(key)"
            }

            columnarReport("   UNWAIT", string)
        }
    }


    func reportOp(_ identifier: ZOperationID, _ mode: ZStorageMode, _ iCount: Int) {
        if  self.debug {
            let   count = iCount <= 0 ? "" : "\(iCount)"
            var message = "\(String(describing: identifier)) \(count)"

            message.appendSpacesToLength(gLogTabStop - 2)
            self.report("\(message)• \(mode)")
        }
    }
}
