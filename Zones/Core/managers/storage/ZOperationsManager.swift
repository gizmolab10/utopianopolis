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
    case switchers
    case file
    case here
    case fetch
    case flush // zones, manifests, switchers
    case children
    case unsubscribe
    case subscribe
    case create
    case parent
    case merge
    case root
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


    func root(_ onCompletion: @escaping Closure) {
        setupAndRun([.root, .children, .flush]) { onCompletion() }
    }


    func families(_ onCompletion: @escaping Closure) {
        setupAndRun([.parent, .children]) { onCompletion() }
    }


    func sync(_ onCompletion: @escaping Closure) {
        setupAndRun([.create, .fetch, .parent, .children, .merge, .flush]) { onCompletion() }
    }


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
            let saved = gStorageMode
            onReady   = onCompletion

            for identifier in identifiers {
                let operation = BlockOperation {
                    // self.report(String(describing: identifier))

                    self          .invokeOn(identifier, mode: saved) {

                        if gStorageMode == .mine || [.file, .ready, .here, .root, .cloud, .subscribe, .unsubscribe].contains(identifier) {
                            self    .finish(identifier, mode: saved)
                        } else {
                            self  .invokeOn(identifier, mode: .mine) {
                                self.finish(identifier, mode: saved)
                            }
                        }
                    }
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
        let               operation = waitingOps[identifier]!
        self.waitingOps[identifier] = nil
        gStorageMode                = mode

        operation.finish()
    }


    func invokeOn(_ identifier: ZOperationID, mode: ZStorageMode, onCompletion: Closure?) {
        gStorageMode = mode

        switch identifier {
        case .file:        zfileManager.restore();                  onCompletion?()  ; break
        case .root:        cloudManager.establishRootAsHere(mode) { onCompletion?() }; break
        case .cloud:       cloudManager.fetchCloudZones    (mode) { onCompletion?() }; break
        case .manifest:    cloudManager.fetchManifest      (mode) { onCompletion?() }; break
        case .switchers:   cloudManager.fetchSwitchers     (mode) { onCompletion?() }; break
        case .here:       travelManager.establishHere      (mode) { onCompletion?() }; break // TODO: BROKEN
        case .children:    cloudManager.fetchChildren      (mode) { onCompletion?() }; break
        case .parent:      cloudManager.fetchParents       (mode) { onCompletion?() }; break
        case .unsubscribe: cloudManager.unsubscribe        (mode) { onCompletion?() }; break
        case .subscribe:   cloudManager.subscribe          (mode) { onCompletion?() }; break
        case .create:      cloudManager.create             (mode) { onCompletion?() }; break
        case .fetch:       cloudManager.fetch              (mode) { onCompletion?() }; break
        case .merge:       cloudManager.merge              (mode) { onCompletion?() }; break
        case .flush:       cloudManager.flush              (mode) { onCompletion?() }; break
        case .ready:       becomeReady                     (mode) { onCompletion?() }; break
        }
    }


    func becomeReady(_ mode: ZStorageMode, onCompletion: Closure?) {
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

        onCompletion?()
    }
}
