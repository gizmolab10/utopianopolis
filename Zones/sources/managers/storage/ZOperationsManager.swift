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
    case root
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
    case none
}


class ZOperationsManager: NSObject {


    var onAvailable:        Closure?
    var currentMode:   ZStorageMode? = nil
    var   currentOp =  ZOperationID   .none
    var  waitingOps = [ZOperationID  : BlockOperation] ()
    var       debug = false
    let       queue = OperationQueue()


    // MARK:- API
    // MARK:-


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
    func       root(_ onCompletion: @escaping Closure) { setupAndRun([.root,                              .save, .children]) { onCompletion() } }
    func     parent(_ onCompletion: @escaping Closure) { setupAndRun([                   .parent                          ]) { onCompletion() } }
    func   families(_ onCompletion: @escaping Closure) { setupAndRun([                   .parent,                .children]) { onCompletion() } }
    func   undelete(_ onCompletion: @escaping Closure) { setupAndRun([.undelete, .fetch, .parent,         .save, .children]) { onCompletion() } }
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
        if  let   prior = onAvailable {         // if already set
            onAvailable = {                     // encapsulate it with subsequent setup for new operation identifiers
                prior()
                self.setupAndRun(operationIDs) { onCompletion() }
            }
        } else {
            queue.isSuspended = true
            onAvailable       = onCompletion
            let         saved = gStorageMode
            let        isMine = [.mine].contains(saved)

            for operationID in operationIDs + [.available] {
                let                     operation = BlockOperation {
                    self               .currentOp = operationID // if hung, it happened inside this op
                    var  recurse: IntegerClosure? = nil         // declare closure first, so compiler will let it recurse
                    let             skipFavorites = operationID != .here
                    let                      full = [.unsubscribe, .subscribe, .favorites, .manifest, .toRoot, .cloud, .root, .here].contains(operationID)
                    let forCurrentStorageModeOnly = [.file, .available, .parent, .children, .authenticate                          ].contains(operationID)
                    let        cloudModes: ZModes = [.mine, .everyone]
                    let             modes: ZModes = !full && (forCurrentStorageModeOnly || isMine) ? [saved] : skipFavorites ? cloudModes : cloudModes + [.favorites]

                    recurse = { index in
                        if index >= modes.count {
                            self.finishOperation(for: operationID)
                        } else {
                            let         mode = modes[index]
                            self.currentMode = mode             // if hung, it happened in this mode
                            self.invoke(operationID, mode, logic) { iError in
                                if let error = iError as? Error {
                                    self.finishOperation(for: operationID)
                                    self.report(error)
                                } else {
                                    recurse?(index + 1)         // recurse
                                }
                            }
                        }
                    }

                    recurse?(0)
                }

                waitingOps[operationID] = operation
                
                addOperation(operation)
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


    func invoke(_ identifier: ZOperationID, _ mode: ZStorageMode, _ logic: ZRecursionLogic? = nil, _ onCompletion: AnyClosure?) {
        if identifier == .available {
            becomeAvailable()
        } else if mode != .favorites || identifier == .here {
            let remote          = gRemoteStoresManager
            let report          = { (iCount: Int) in
                if  self.debug {
                    let   count = iCount <= 0 ? "" : "\(iCount)"
                    var message = "\(String(describing: identifier)) \(count)"

                    message.appendSpacesToLength(gLogTabStop - 2)
                    self.report("\(message)• \(mode)")
                }
            }

            let signalBack = { (iResult: Any?) in
                if let error = iResult as? Error {
                    onCompletion?(error)
                } else if let count  = iResult as? Int {
                    if count == 0 {
                        onCompletion?(nil)
                    } else if identifier != .available {
                        report(count)
                    }
                }
            }

            let complete = { (iCount: Int) in signalBack(iCount) }

            report(0)

            switch identifier {
            case .file:                 gFileManager.restore  (from:          mode);    complete(0)
            case .here:                 remote               .establishHere  (mode,     complete)
            case .root:                 remote               .establishRoot  (mode,     complete)
            default: let cloudManager = remote               .cloudManagerFor(mode)
                switch identifier {
                case .authenticate: remote.authenticate                      (          signalBack)
                case .cloud:        cloudManager.fetchCloudZones             (          complete)
                case .favorites:    cloudManager.fetchFavorites              (          complete)
                case .manifest:     cloudManager.fetchManifest               (          complete)
                case .children:     cloudManager.fetchChildren               (logic,    complete)
                case .parent:       cloudManager.fetchParents                (.restore, complete)
                case .toRoot:       cloudManager.fetchParents                (.all,     complete)
                case .unsubscribe:  cloudManager.unsubscribe                 (          complete)
                case .undelete:     cloudManager.undeleteAll                 (          complete)
                case .emptyTrash:   cloudManager.emptyTrash                  (          complete)
                case .subscribe:    cloudManager.subscribe                   (          complete)
                case .bookmarks:    cloudManager.bookmarks                   (          complete)
                case .create:       cloudManager.create                      (          complete)
                case .fetch:        cloudManager.fetch                       (          complete)
                case .merge:        cloudManager.merge                       (          complete)
                case .save:         cloudManager.save                        (          complete)
                default: break
                }
            }

            return
        }

        onCompletion?(nil)
    }


    func becomeAvailable() {
        currentMode     = nil
        currentOp       = .available

        if  let closure = onAvailable {
            onAvailable = nil
            FOREGROUND {
                closure()
            }
        }
    }
}
