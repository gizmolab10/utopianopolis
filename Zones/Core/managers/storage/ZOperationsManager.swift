//
//  ZOperationsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


enum ZOperationID: Int {
    case ready
    case cloud
    case manifest
    case root
    case favorites
    case file
    case here
    case fetch
    case flush // zones, manifests, favorites
    case children
    case unsubscribe
    case subscribe
    case emptyTrash
    case undelete
    case create
    case parent
    case merge
}


class ZOperationsManager: NSObject {


    var    onReady: Closure?
    var    isReady = false
    var waitingOps = [ZOperationID : BlockOperation] ()
    let      queue = OperationQueue()


    // MARK:- API
    // MARK:-


    func startup(_ onCompletion: @escaping Closure) {
        var operationIDs: [ZOperationID] = []

        for sync in ZOperationID.cloud.rawValue...ZOperationID.subscribe.rawValue {
            operationIDs.append(ZOperationID(rawValue: sync)!)
        }

        setupAndRun(operationIDs) { onCompletion() }
    }


    func travel(_ onCompletion: @escaping Closure) {
        var operationIDs: [ZOperationID] = []

        for sync in ZOperationID.here.rawValue...ZOperationID.subscribe.rawValue {
            operationIDs.append(ZOperationID(rawValue: sync)!)
        }

        setupAndRun(operationIDs) { onCompletion() }
    }


    func       sync(_ onCompletion: @escaping Closure) { setupAndRun([.create,   .fetch, .parent, .children, .merge, .flush]) { onCompletion() } }
    func       root(_ onCompletion: @escaping Closure) { setupAndRun([.root,                      .children,         .flush]) { onCompletion() } }
    func   families(_ onCompletion: @escaping Closure) { setupAndRun([                   .parent, .children                ]) { onCompletion() } }
    func   undelete(_ onCompletion: @escaping Closure) { setupAndRun([.undelete, .fetch, .parent, .children,         .flush]) { onCompletion() } }
    func emptyTrash(_ onCompletion: @escaping Closure) { setupAndRun([.emptyTrash                                          ]) { onCompletion() } }


    func children(_ recursively: Bool, onCompletion: @escaping Closure) {
        gRecursivelyExpand     = recursively
        
        setupAndRun([.children]) {
            gRecursivelyExpand = false

            onCompletion()
        }
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


    private func setupAndRun(_ operationIDs: [ZOperationID], onCompletion: @escaping Closure) {
        var identifiers   = operationIDs
        isReady           = false;
        queue.isSuspended = true

        identifiers.append(.ready)

        if let prior = onReady {
            onReady = {
                prior()
                self.setupAndRun(operationIDs) { onCompletion() }
            }
        } else {
            onReady    = onCompletion
            let  saved = gStorageMode
            let isMine = saved == .mine

            for identifier in identifiers {
                let  operation = BlockOperation {
                    let                   simple = [.file, .ready, .cloud, .parent, .children, .subscribe, .unsubscribe].contains(identifier)
                    let    modes: [ZStorageMode] = simple || isMine ? [saved] : [.mine, .everyone, .favorites]
                    var closure: IntegerClosure? = nil

                    closure = { (index: Int) in
                        if index < modes.count {
                            self.invoke(identifier, mode: modes[index]) {
                                closure?(index + 1)
                            }
                        } else {
                            self.finish(identifier, mode: saved)
                        }
                    }

                    closure?(0)
                }

                waitingOps[identifier] = operation
                
                addOperation(operation)
            }
        }

        queue.isSuspended = false

        dispatchAsyncInForegroundAfter(0.5) {
            controllersManager.displayActivity()
        }
    }


    func finish(_ identifier: ZOperationID, mode: ZStorageMode) {
        gStorageMode = mode

        if let operation = waitingOps[identifier] {
            waitingOps[identifier] = nil

            operation.bandaid()
        }
    }


    func invoke(_ identifier: ZOperationID, mode: ZStorageMode, _ onCompletion: Closure?) {
        gStorageMode = mode

        let report = { (iCount: Int) -> Void in
            if iCount == 0 {
                onCompletion?()
//            } else {
//                self.report("\(String(describing: identifier)) \(iCount) \(mode)")
            }
        }

        switch identifier {
        case .file:        zfileManager.restore();                report(0); break
        case .root:        cloudManager.establishRootAsHere(mode, report); break
        case .cloud:       cloudManager.fetchCloudZones    (mode, report); break
        case .manifest:    cloudManager.fetchManifest      (mode, report); break
        case .favorites:   cloudManager.fetchFavorites     (mode, report); break
        case .here:       travelManager.establishHere      (mode, report); break // TODO: BROKEN
        case .children:    cloudManager.fetchChildren      (mode, report); break
        case .parent:      cloudManager.fetchParents       (mode, report); break
        case .unsubscribe: cloudManager.unsubscribe        (mode, report); break
        case .subscribe:   cloudManager.subscribe          (mode, report); break
        case .emptyTrash:  cloudManager.emptyTrash         (mode, report); break
        case .undelete:    cloudManager.undelete           (mode, report); break
        case .create:      cloudManager.create             (mode, report); break
        case .fetch:       cloudManager.fetch              (mode, report); break
        case .merge:       cloudManager.merge              (mode, report); break
        case .flush:       cloudManager.flush              (mode, report); break
        case .ready:       becomeReady                     (mode, report); break
        }
    }


    func becomeReady(_ mode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        isReady = true;

        controllersManager.displayActivity()

        if let closure = onReady {
            onReady = nil

            dispatchAsyncInForeground {
                closure()

                // self.report("unspin")
                editingManager.handleStalledEvents()
            }
        }

        onCompletion?(0)
    }
}
