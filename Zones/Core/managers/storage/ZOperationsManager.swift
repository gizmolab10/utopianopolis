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
    case file
    case here
    case flush
    case fetch
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

        setupAndRun(operationIDs, onCompletion: onCompletion)
    }


    func travel(_ onCompletion: @escaping Closure) {
        var operationIDs: [ZOperationID] = []

        for sync in ZOperationID.here.rawValue...ZOperationID.subscribe.rawValue {
            operationIDs.append(ZOperationID(rawValue: sync)!)
        }

        setupAndRun(operationIDs, onCompletion: onCompletion)
    }


    func root(_ onCompletion: @escaping Closure) {
        setupAndRun([.root, .children], onCompletion: onCompletion)
    }


    func sync(_ onCompletion: @escaping Closure) {
        setupAndRun([.create, .parent, .children, .merge, .flush], onCompletion: onCompletion)
    }


    func getChildren(_ recursively: Bool, onCompletion: @escaping Closure) {
        recursivelyExpand = recursively
        
        setupAndRun([.children]) {
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
                self.setupAndRun(operationIDs, onCompletion: onCompletion)
            }
        } else {
            onReady = onCompletion

            for identifier in identifiers {
                let op = BlockOperation {
                    self.invokeOn(identifier)
                }

                waitingOps[identifier] = op

                addOperation(op)
            }
        }

        queue.isSuspended = false

        dispatchAsyncInForegroundAfter(0.5) {
            controllersManager.displayActivity()
        }
    }


    func invokeOn(_ identifier: ZOperationID) {
        let          operation = waitingOps[identifier]!
        waitingOps[identifier] = nil

        // report(String(describing: identifier))

        switch identifier {
        case .file:        zfileManager.restore();           operation.finish();   break
        case .root:        cloudManager.establishRootAsHere{ operation.finish() }; break
        case .cloud:       cloudManager.fetchCloudZones    { operation.finish() }; break
        case .here:       travelManager.establishHere      { operation.finish() }; break
        case .children:    cloudManager.fetchChildren      { operation.finish() }; break
        case .parent:      cloudManager.fetchParents       { operation.finish() }; break
        case .unsubscribe: cloudManager.unsubscribe        { operation.finish() }; break
        case .subscribe:   cloudManager.subscribe          { operation.finish() }; break
        case .create:      cloudManager.create             { operation.finish() }; break
        case .fetch:       cloudManager.fetch              { operation.finish() }; break
        case .merge:       cloudManager.merge              { operation.finish() }; break
        case .flush:       cloudManager.flush              { operation.finish() }; break
        case .ready:       becomeReady                     { operation.finish() }; break
        }
    }


    func becomeReady(_ onCompletion: Closure?) {
        recursivelyExpand = false
        isReady           = true;

        controllersManager.displayActivity()

        if let closure = onReady {
            onReady = nil

            dispatchAsyncInForeground {
                closure()

                self.report("unspin")
                editingManager.handleDeferredEvents()
            }
        }

        onCompletion?()
    }
}
