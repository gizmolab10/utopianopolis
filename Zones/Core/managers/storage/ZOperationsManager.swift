//
//  ZOperationsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


enum ZSynchronizationState: Int {
    case ready
    case cloud
    case file
    case root
    case flush
    case fetch
    case children
    case unsubscribe
    case subscribe
    case merge
}


class ZOperationsManager: NSObject {


    var           isReady:                                   Bool = false
    var operationsByState: [ZSynchronizationState:BlockOperation] = [:]
    let             queue:                         OperationQueue = OperationQueue()
    var           onReady: Closure?


    // MARK:- API
    // MARK:-


    func startup(_ block: (() -> Swift.Void)?) {
        var syncStates: [ZSynchronizationState] = []

        for sync in ZSynchronizationState.cloud.rawValue...ZSynchronizationState.subscribe.rawValue {
            syncStates.append(ZSynchronizationState(rawValue: sync)!)
        }

        setupAndRun(syncStates, block: block!)
    }


    func travel(_ block: (() -> Swift.Void)?) {
        var syncStates: [ZSynchronizationState] = []

        for sync in ZSynchronizationState.file.rawValue...ZSynchronizationState.subscribe.rawValue {
            syncStates.append(ZSynchronizationState(rawValue: sync)!)
        }

        setupAndRun(syncStates, block: block!)
    }


    func sync(_ block: (() -> Swift.Void)?) {
        setupAndRun([.merge, .flush], block: block!)
    }


    func getChildren(_ block: (() -> Swift.Void)?) {
        setupAndRun([.children], block: block!)
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


    private func setupAndRun(_ syncStates: [ZSynchronizationState], block: @escaping (() -> Swift.Void)) {
        queue.isSuspended = true
        var states        = syncStates

        states.append(.ready)

        if let prior = onReady {
            onReady = {
                prior()
                self.setupAndRun(syncStates, block: block)
            }
        } else {
            onReady = block

            for state in states {
                let op = BlockOperation {
                    self.invokeOn(state)
                }

                operationsByState[state] = op

                addOperation(op)
            }
        }

        isReady           = false;
        queue.isSuspended = false

        controllersManager.displayActivity()
    }


    func invokeOn(_ state: ZSynchronizationState) {
        let            operation = operationsByState[state]!
        operationsByState[state] = nil

        print(state)

        switch(state) {
        case .file:        zfileManager.restore();        operation.finish();   break
        case .cloud:       cloudManager.fetchCloudZones { operation.finish() }; break
        case .root:        cloudManager.setupRoot       { operation.finish() }; break
        case .fetch:       cloudManager.fetch           { operation.finish() }; break
        case .children:    cloudManager.fetchChildren   { operation.finish() }; break
        case .unsubscribe: cloudManager.unsubscribe     { operation.finish() }; break
        case .subscribe:   cloudManager.subscribe       { operation.finish() }; break
        case .merge:       cloudManager.merge           { operation.finish() }; break
        case .flush:       cloudManager.flush           { operation.finish() }; break
        case .ready:       becomeReady(                   operation);           break
        }
    }


    func becomeReady(_ operation: BlockOperation) {
        isReady = true;

        controllersManager.displayActivity()

        if onReady != nil {
            onReady!()
            print("unspun")

            onReady = nil
        }

        operation.finish()

        editingManager.callOnReady()
    }
}
