//
//  ZOperationsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


class ZOperationsManager: NSObject {


    var    isReady:                                   Bool = false
    var operations: [ZSynchronizationState:BlockOperation] = [:]
    let      queue:                         OperationQueue = OperationQueue()


    func setupAndRun() {
        var syncStates: [Int] = []

        for sync in ZSynchronizationState.restore.rawValue...ZSynchronizationState.subscribe.rawValue {
            syncStates.append(sync)
        }

        setupAndRun(syncStates)
    }


    func setupAndRun(_ syncStates: [Int]) {
        queue.isSuspended                 = true
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService            = .background
        var states                        = syncStates
        var priorOp:      BlockOperation? = nil

        states.append(ZSynchronizationState.ready.rawValue)

        for state in states {
            let state = ZSynchronizationState(rawValue: state)!
            let    op = BlockOperation { self.invokeOn(state) }

            if priorOp != nil {
                op.addDependency(priorOp!)
            }

            priorOp           = op
            operations[state] = op

            queue.addOperation(op)
        }

        queue.isSuspended = false
    }


    func invokeOn(_ state: ZSynchronizationState) {
        let operation = operations[state]!

        print(state)

        switch(state) {
        case .restore:     zfileManager.restore();          operation.finish();   break
        case .fetch:       cloudManager.fetchOnCompletion { operation.finish() }; break
        case .root:        cloudManager.setupRootWith      (operation:operation); break
        case .unsubscribe: cloudManager.unsubscribeWith    (operation:operation); break
        case .subscribe:   cloudManager.subscribeWith      (operation:operation); break
        case .ready:                                           finish(operation); break
        }
    }


    func finish(_ operation: BlockOperation) {
        isReady = true;

        operation.finish()
        controllersManager.updateToClosures(nil, regarding: .data)
    }
}
