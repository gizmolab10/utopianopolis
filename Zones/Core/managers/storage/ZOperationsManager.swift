//
//  ZOperationsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation


enum ZOperationID: Int {
    case cloud
    case root
    case manifest
    case favorites
    case file
    case here
    case fetch
    case children
    case toRoot
    case save // zones, manifests, favorites
    case unsubscribe
    case subscribe

    case emptyTrash
    case undelete
    case create
    case parent
    case merge
    case ready
    case none
}


class ZOperationsManager: NSObject {


    var     onReady:        Closure?
    var currentMode:   ZStorageMode? = nil
    var   currentOp:   ZOperationID = .none
    var  waitingOps = [ZOperationID : BlockOperation] ()
    var       debug = false
    let       queue = OperationQueue()


    // MARK:- API
    // MARK:-


    func startup(_ onCompletion: @escaping Closure) {
        var operationIDs: [ZOperationID] = []

        for sync in ZOperationID.cloud.rawValue...ZOperationID.toRoot.rawValue {
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


    func       sync(_ onCompletion: @escaping Closure) { setupAndRun([.create,   .fetch, .parent, .children, .merge, .save]) { onCompletion() } }
    func       save(_ onCompletion: @escaping Closure) { setupAndRun([.create,                               .merge, .save]) { onCompletion() } }
    func       root(_ onCompletion: @escaping Closure) { setupAndRun([.root,                      .children,         .save]) { onCompletion() } }
    func     parent(_ onCompletion: @escaping Closure) { setupAndRun([                   .parent                          ]) { onCompletion() } }
    func   families(_ onCompletion: @escaping Closure) { setupAndRun([                   .parent, .children               ]) { onCompletion() } }
    func   undelete(_ onCompletion: @escaping Closure) { setupAndRun([.undelete, .fetch, .parent, .children,         .save]) { onCompletion() } }
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
        if let prior = onReady {
            onReady = {
                self.dispatchAsyncInForeground { // prevent recursion pile-up on stack
                    prior()
                    self.setupAndRun(operationIDs) { onCompletion() }
                }
            }
        } else {
            let identifiers   = operationIDs + [.ready]
            queue.isSuspended = true
            onReady           = onCompletion
            let         saved = gStorageMode
            let        isMine = [.mine].contains(saved)

            for operationID in identifiers {
                let                     operation = BlockOperation {
                    self               .currentOp = operationID // if hung, it happened inside this op
                    var  closure: IntegerClosure? = nil     // declare closure first, so compiler will let it recurse
                    let             skipFavorites = operationID != .here
                    let                      full = [.unsubscribe, .subscribe, .favorites, .manifest, .toRoot, .cloud, .root, .here].contains(operationID)
                    let forCurrentStorageModeOnly = [.file, .ready, .parent, .children]                                             .contains(operationID)
                    let        cloudModes: ZModes = [.mine, .everyone]
                    let             modes: ZModes = !full && (forCurrentStorageModeOnly || isMine) ? [saved] : skipFavorites ? cloudModes : cloudModes + [.favorites]

                    closure = { index in
                        if index >= modes.count {
                            self.finishOperation(for: operationID)
                        } else {
                            let mode = modes[index]
                            self.currentMode = mode         // if hung, it happened in this mode
                            self.invoke(operationID, mode, logic) {
                                closure?(index + 1)         // recurse
                            }
                        }
                    }

                    closure?(0)
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


    func invoke(_ identifier: ZOperationID, _ mode: ZStorageMode, _ logic: ZRecursionLogic? = nil, _ onCompletion: Closure?) {
        if identifier == .ready {
            becomeReady()
        } else if mode != .favorites || identifier == .here {
            let report          = { (iCount: Int) in
                if  self.debug {
                    let   count = iCount <= 0 ? "" : "\(iCount)"
                    var message = "\(String(describing: identifier)) \(count)"

                    message.appendSpacesToLength(gLogTabStop - 2)
                    self.report("\(message)• \(mode)")
                }
            }

            let complete        = { (iCount: Int) -> Void in
                if iCount      == 0 {
                    onCompletion?()
                } else if identifier != ZOperationID.ready {
                    report(iCount)
                }
            }

            report(0)

            switch identifier {
            case .file:                 gFileManager.restore (from:          mode); complete(0)
            case .here:                 gRemoteStoresManager.establishHere  (mode,  complete)
            case .root:                 gRemoteStoresManager.establishRoot  (mode,  complete)
            default: let cloudManager = gRemoteStoresManager.cloudManagerFor(mode)
                switch identifier {
                case .cloud:       cloudManager.fetchCloudZones             (       complete)
                case .favorites:   cloudManager.fetchFavorites              (       complete)
                case .manifest:    cloudManager.fetchManifest               (       complete)
                case .children:    cloudManager.fetchChildren               (logic, complete)
                case .parent:      cloudManager.fetchParents                (       complete)
                case .unsubscribe: cloudManager.unsubscribe                 (       complete)
                case .toRoot:      cloudManager.fetchToRoot                 (       complete)
                case .undelete:    cloudManager.undeleteAll                 (       complete)
                case .emptyTrash:  cloudManager.emptyTrash                  (       complete)
                case .subscribe:   cloudManager.subscribe                   (       complete)
                case .create:      cloudManager.create                      (       complete)
                case .fetch:       cloudManager.fetch                       (       complete)
                case .merge:       cloudManager.merge                       (       complete)
                case .save:        cloudManager.save                        (       complete)
                default: break
                }
            }

            return
        }

        onCompletion?()
    }


    func becomeReady() {
        currentMode     = nil
        currentOp       = .ready

        if  let closure = onReady {
            onReady     = nil
            dispatchAsyncInForeground {
                closure()
            }
        }
    }
}
