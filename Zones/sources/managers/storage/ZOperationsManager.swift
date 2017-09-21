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
    case favorites
    case file
    case here
    case fetch
    case toRoot
    case children
    case save // zones, manifests, favorites
    case unsubscribe
    case subscribe

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


    var invokeResponse:  AnyClosure?
    var onAvailable:        Closure?
    var lastOpStart:           Date? = nil
    var currentMode:   ZStorageMode? = nil
    var   currentOp =  ZOperationID   .none
    var  waitingOps = [ZOperationID  : BlockOperation] ()
    var       debug = false
    let       queue = OperationQueue()


    // MARK:- API
    // MARK:-


    var isLate: Bool {
        return lastOpStart != nil && lastOpStart!.timeIntervalSinceNow < -30.0
    }


    func startUp(_ onCompletion: @escaping Closure) {
        var operationIDs: [ZOperationID] = []

        for sync in ZOperationID.authenticate.rawValue...ZOperationID.children.rawValue {
            operationIDs.append(ZOperationID(rawValue: sync)!)
        }

        setupAndRun(operationIDs) { onCompletion() }
    }
    

    func finishUp(_ onCompletion: @escaping Closure) {
        var operationIDs: [ZOperationID] = []

        for sync in ZOperationID.save.rawValue...ZOperationID.subscribe.rawValue {
            operationIDs.append(ZOperationID(rawValue: sync)!)
        }

        setupAndRun(operationIDs) { onCompletion() }
    }


    func travel(_ onCompletion: @escaping Closure) {
        var operationIDs: [ZOperationID] = []

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
    func  bookmarks(_ onCompletion: @escaping Closure) { setupAndRun([.bookmarks                                          ]) { onCompletion() } }
    func emptyTrash(_ onCompletion: @escaping Closure) { setupAndRun([.emptyTrash                                         ]) { onCompletion() } }


    func children(_ recursing: ZRecursionType, _ iRecursiveGoal: Int? = nil, onCompletion: @escaping Closure) {
        let logic = ZRecursionLogic(recursing, iRecursiveGoal)

        setupAndRun([.children], logic: logic) { onCompletion() }
    }


    // MARK:- internals
    // MARK:-


    func addOperation(_ op: BlockOperation) {
        if let prior = queue.operations.last {
            op.addDependency(prior)
        } else {
            queue.qualityOfService            = .background
            queue.maxConcurrentOperationCount = 1
        }

        queue.addOperation(op)
    }


    private func setupAndRun(_ operationIDs: [ZOperationID], logic: ZRecursionLogic? = nil, onCompletion: @escaping Closure) {
        if gIsLate {
            onCompletion()
        }

        if  let   prior = onAvailable {         // if already set
            onAvailable = {                     // encapsulate it with subsequent setup for new operation identifiers
                prior()
                self.setupAndRun(operationIDs) { onCompletion() }
            }
        } else {
            queue.isSuspended = true
            onAvailable       = onCompletion
            let         saved = gStorageMode
            let        isMine = [.mineMode].contains(saved)

            for operationID in operationIDs + [.available] {
                let                blockOperation = BlockOperation {
                    self               .currentOp = operationID             // if hung, it happened inside this op
                    var  performOpForModeAtIndex: IntegerClosure? = nil     // declare closure first, so compiler will let it recurse
                    let             skipFavorites = operationID != .here
                    let                      full = [.unsubscribe, .subscribe, .favorites, .manifest, .toRoot, .cloud, .roots, .here].contains(operationID)
                    let forCurrentStorageModeOnly = [.file, .available, .parent, .children, .authenticate                           ].contains(operationID)
                    let        cloudModes: ZModes = [.mineMode, .everyoneMode]
                    let             modes: ZModes = !full && (forCurrentStorageModeOnly || isMine) ? [saved] : skipFavorites ? cloudModes : cloudModes + [.favoritesMode]

                    performOpForModeAtIndex = { index in
                        if index >= modes.count {
                            self.finishOperation(for: operationID)
                        } else {
                            let                mode = modes[index]
                            self    .invokeResponse = { (iResult: Any?) in
                                self.invokeResponse = nil
                                self   .lastOpStart = nil

                                self.signalBack(operationID, mode, iResult) { iError in
                                    if let error = iError as? Error {
                                        self.finishOperation(for: operationID)
                                        self.report(error)
                                    } else {
                                        performOpForModeAtIndex?(index + 1)         // recurse
                                    }
                                }
                            }

                            self.invoke(operationID, mode, logic)
                        }
                    }

                    performOpForModeAtIndex?(0)
                }

                waitingOps[operationID] = blockOperation

                addOperation(blockOperation)
            }

            queue.isSuspended = false
        }
    }


    func finishOperation(for identifier: ZOperationID) {
        if let operation = waitingOps[identifier] {
            waitingOps[identifier] = nil

            operation.bandaid()
        }
    }


    func invoke(_ identifier: ZOperationID, _ mode: ZStorageMode, _ logic: ZRecursionLogic? = nil) {
        if identifier == .available {
            becomeAvailable()
        } else if     mode != .favoritesMode || identifier == .here {
            let      remote = gRemoteStoresManager
            currentMode     = mode             // if hung, it happened in this mode
            lastOpStart     = Date()

            reportOp(identifier, mode, 0)

            switch identifier {
            case .file:                 gFileManager.restore  (from:          mode);    invokeResponse?(0)
            case .here:                 remote               .establishHere  (mode,     invokeResponse)
            case .roots:                remote               .establishRoot  (mode,     invokeResponse)
            default: let cloudManager = remote               .cloudManagerFor(mode)
                switch identifier {
                case .authenticate: remote.authenticate                      (          invokeResponse)
                case .cloud:        cloudManager.fetchCloudZones             (          invokeResponse)
                case .favorites:    cloudManager.fetchFavorites              (          invokeResponse)
                case .manifest:     cloudManager.fetchManifest               (          invokeResponse)
                case .children:     cloudManager.fetchChildren               (logic,    invokeResponse)
                case .parent:       cloudManager.fetchParents                (.restore, invokeResponse)
                case .toRoot:       cloudManager.fetchParents                (.all,     invokeResponse)
                case .unsubscribe:  cloudManager.unsubscribe                 (          invokeResponse)
                case .undelete:     cloudManager.undeleteAll                 (          invokeResponse)
                case .emptyTrash:   cloudManager.emptyTrash                  (          invokeResponse)
                case .trash:        cloudManager.fetchTrash                  (          invokeResponse)
                case .subscribe:    cloudManager.subscribe                   (          invokeResponse)
                case .bookmarks:    cloudManager.bookmarks                   (          invokeResponse)
                case .create:       cloudManager.create                      (          invokeResponse)
                case .fetch:        cloudManager.fetch                       (          invokeResponse)
                case .merge:        cloudManager.merge                       (          invokeResponse)
                case .save:         cloudManager.save                        (          invokeResponse)
                default: break
                }
            }

            return
        }
    }


    func signalBack(_ identifier: ZOperationID, _ mode: ZStorageMode, _ iResult: Any?, _ onCompletion: AnyClosure?) {
        if let error = iResult as? Error {
            onCompletion?(error)
        } else if let count  = iResult as? Int {
            if count == 0 {
                onCompletion?(nil)
            } else if identifier != .available {
                reportOp(identifier, mode, count)
            }
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


    func clearAllWaitingOps() {
        for op in waitingOps.keys {
            finishOperation(for: op)
        }
    }


    func becomeAvailable() {
        currentMode     = nil
        currentOp       = .available

        clearAllWaitingOps()
        invokeResponse?(nil)

        if  let closure = onAvailable {
            onAvailable = nil
            FOREGROUND {
                closure()
            }
        }
    }
}
