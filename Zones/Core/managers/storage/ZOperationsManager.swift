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
    case toRoot
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

        for sync in ZOperationID.here.rawValue...ZOperationID.children.rawValue {
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
        if let prior = onReady {
            onReady = {
                self.dispatchAsyncInForeground { // prevent recursion pile-up on stack
                    prior()
                    self.setupAndRun(operationIDs) { onCompletion() }
                }
            }
        } else {
            let identifiers   = operationIDs + [.ready]
            isReady           = false;
            queue.isSuspended = true
            onReady           = onCompletion
            let         saved = gStorageMode
            let        isMine = [.mine].contains(saved)

            for identifier in identifiers {
                let                     operation = BlockOperation {
                    var  closure: IntegerClosure? = nil     // allow this closure to recurse
                    let             skipFavorites = identifier != .here
                    let                      full = [.unsubscribe, .subscribe, .favorites, .manifest, .toRoot, .cloud, .root, .here].contains(identifier)
                    let forCurrentStorageModeOnly = [.file, .ready, .parent, .children]                                             .contains(identifier)
                    let     modes: [ZStorageMode] = !full && (forCurrentStorageModeOnly || isMine) ? [saved] : skipFavorites ? [.mine, .everyone] : [.mine, .everyone, .favorites]

                    closure = { index in
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

            queue.isSuspended = false

            dispatchAsyncInForegroundAfter(0.5) {
                gControllersManager.displayActivity()
            }
        }
    }


    func finishOperation(for identifier: ZOperationID) {
        if let operation = waitingOps[identifier] {
            waitingOps[identifier] = nil

            operation.bandaid()
        }
    }


    func invoke(_ identifier: ZOperationID, mode: ZStorageMode, _ optional: Int? = nil, _ onCompletion: Closure?) {
        if identifier == .ready {
            becomeReady()
        } else if mode != .favorites || identifier == .here {
            let        complete = { (iCount: Int) -> Void in
                if iCount      == 0 {
                    onCompletion?()
                } else if self.debug && identifier != ZOperationID.ready {
                    let   count = iCount < 0 ? "" : "\(iCount)"
                    var message = "\(String(describing: identifier)) \(count)"

                    message.appendSpacesToLength(13)
                    self.note("\(message)• \(mode)")
                }
            }
            
            switch identifier {
            case .file:           gfileManager.restore (from:        mode   ); complete(0)
            case .here:           gRemoteStoresManager.establishHere(mode,     complete)
            case .root:           gRemoteStoresManager.establishRoot(mode,     complete)
            default:
                let cloudManager = gRemoteStoresManager.cloudManagerFor(mode)

                switch identifier {
                case .cloud:       cloudManager.fetchCloudZones     (          complete)
                case .favorites:   cloudManager.fetchFavorites      (          complete)
                case .manifest:    cloudManager.fetchManifest       (          complete)
                case .children:    cloudManager.fetchChildren       (optional, complete)
                case .parent:      cloudManager.fetchParents        (          complete)
                case .unsubscribe: cloudManager.unsubscribe         (          complete)
                case .toRoot:      cloudManager.fetchToRoot         (          complete)
                case .undelete:    cloudManager.undeleteAll         (          complete)
                case .emptyTrash:  cloudManager.emptyTrash          (          complete)
                case .subscribe:   cloudManager.subscribe           (          complete)
                case .create:      cloudManager.create              (          complete)
                case .fetch:       cloudManager.fetch               (          complete)
                case .merge:       cloudManager.merge               (          complete)
                case .flush:       cloudManager.flush               (          complete)
                default: break
                }
            }

            return
        }

        onCompletion?()
    }


    func becomeReady() {
        isReady = true;

        gControllersManager.displayActivity()

        if let closure = onReady {
            onReady = nil

            dispatchAsyncInForeground {
                closure()

                gEditingManager.handleStalledEvents()
            }
        }
    }
}
