//
//  ZOperationsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation


enum ZOperationID: Int {
    case root
    case cloud
    case manifest
    case favorites
    case file
    case here
    case scaffold
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
    case ready
}


class ZOperationsManager: NSObject {


    var    onReady: Closure?
    var    isReady = false
    var      debug = true
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
    func     parent(_ onCompletion: @escaping Closure) { setupAndRun([                   .parent                           ]) { onCompletion() } }
    func   families(_ onCompletion: @escaping Closure) { setupAndRun([                   .parent, .children                ]) { onCompletion() } }
    func   undelete(_ onCompletion: @escaping Closure) { setupAndRun([.undelete, .fetch, .parent, .children,         .flush]) { onCompletion() } }
    func emptyTrash(_ onCompletion: @escaping Closure) { setupAndRun([.emptyTrash                                          ]) { onCompletion() } }


    func children(recursiveGoal: Int? = nil, onCompletion: @escaping Closure) {
        setupAndRun([.children], optional: recursiveGoal) { onCompletion() }
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


    private func setupAndRun(_ operationIDs: [ZOperationID], optional: Int? = nil, onCompletion: @escaping Closure) {
        var identifiers   = operationIDs
        isReady           = false;
        queue.isSuspended = true

        identifiers.append(.ready)

        if let prior = onReady {
            onReady = {
                self.dispatchAsyncInForeground { // prevent recursion pile-up on stack
                    prior()
                    self.setupAndRun(operationIDs) { onCompletion() }
                }
            }
        } else {
            onReady    = onCompletion
            let  saved = gStorageMode
            let isMine = [.mine].contains(saved)

            for identifier in identifiers {
                let  operation = BlockOperation {
                    var  closure: IntegerClosure? = nil     // allow this closure to recurse
                    let                      full = [.root, .favorites].contains(identifier)
                    let forCurrentStorageModeOnly = [.here, .file, .ready, .cloud, .parent, .children, .subscribe, .unsubscribe].contains(identifier)
                    let     modes: [ZStorageMode] = !full && (forCurrentStorageModeOnly || isMine) ? [saved] : [.mine, .everyone, .favorites]

                    closure = { (index: Int) in
                        if index >= modes.count {
                            self.finishOperation(for: identifier)
                        } else {
                            self.invoke(identifier, mode: modes[index], optional) {
                                closure?(index + 1)         // recurse
                            }
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
            gControllersManager.displayActivity()
        }
    }


    func finishOperation(for identifier: ZOperationID) {
        if let operation = waitingOps[identifier] {
            waitingOps[identifier] = nil

            operation.bandaid()
        }
    }


    func invoke(_ identifier: ZOperationID, mode: ZStorageMode, _ optional: Int? = nil, _ onCompletion: Closure?) {
        let complete = { (iCount: Int) -> Void in
            if iCount == 0 {
                onCompletion?()
            }

            if self.debug && identifier != ZOperationID.ready {
                self.report("\(String(describing: identifier)) \(iCount) \(mode)")
            }
        }

        switch identifier {
        case .file:         gfileManager.restore  (from: mode);          complete(0); break
        case .root:        gCloudManager.establishRoot  (mode,           complete);   break
        case .manifest:    gCloudManager.fetchManifest  (mode,           complete);   break
        case .favorites:   gCloudManager.fetchFavorites (mode,           complete);   break
        case .here:       gTravelManager.establishHere  (mode,           complete);   break // TODO: BROKEN
        case .scaffold:    gCloudManager.fetchScaffold  (mode,           complete);   break
        case .children:    gCloudManager.fetchChildren  (mode, optional, complete);   break
        case .parent:      gCloudManager.fetchParents   (mode,           complete);   break
        case .unsubscribe: gCloudManager.unsubscribe    (mode,           complete);   break
        case .cloud:       gCloudManager.cloudLogic     (mode,           complete);   break
        case .emptyTrash:  gCloudManager.emptyTrash     (mode,           complete);   break
        case .subscribe:   gCloudManager.subscribe      (mode,           complete);   break
        case .undelete:    gCloudManager.undelete       (mode,           complete);   break
        case .create:      gCloudManager.create         (mode,           complete);   break
        case .fetch:       gCloudManager.fetch          (mode,           complete);   break
        case .merge:       gCloudManager.merge          (mode,           complete);   break
        case .flush:       gCloudManager.flush          (mode,           complete);   break
        case .ready:                     becomeReady    (mode,           complete);   break
        }
    }


    func becomeReady(_ mode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        isReady = true;

        gControllersManager.displayActivity()

        if let closure = onReady {
            onReady = nil

            dispatchAsyncInForeground {
                closure()

                gEditingManager.handleStalledEvents()
            }
        }
        
        onCompletion?(0)
    }
}
