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
    var    onReady: Closure?



    func fullRun(_ block: (() -> Swift.Void)?) {
        var syncStates: [Int] = []

        for sync in ZSynchronizationState.cloud.rawValue...ZSynchronizationState.subscribe.rawValue {
            syncStates.append(sync)
        }

        setupAndRun(syncStates, block: block!)
    }


    func travel(_ block: (() -> Swift.Void)?) {
        var syncStates: [Int] = []

        for sync in ZSynchronizationState.restore.rawValue...ZSynchronizationState.subscribe.rawValue {
            syncStates.append(sync)
        }

        setupAndRun(syncStates, block: block!)
    }


    func sync(_ block: (() -> Swift.Void)?) {
        var syncStates: [Int] = []

        for sync in ZSynchronizationState.merge.rawValue...ZSynchronizationState.flush.rawValue {
            syncStates.append(sync)
        }

        setupAndRun(syncStates, block: block!)
    }


    func setupAndRun(_ syncStates: [Int], block: @escaping (() -> Swift.Void)) {
        var states                   = syncStates
        var priorOp: BlockOperation? = nil
        queue.isSuspended            = true

        states.append(ZSynchronizationState.ready.rawValue)

        if queue.operations.count > 0 {
            let op = BlockOperation { self.setupAndRun(syncStates, block: block) }

            op.addDependency(queue.operations.last!)
            queue.addOperation(op)
        } else {
            onReady                           = block
            queue.qualityOfService            = .background
            queue.maxConcurrentOperationCount = 1

            for state in states {
                let syncState = ZSynchronizationState(rawValue: state)!
                let        op = BlockOperation { self.invokeOn(syncState) }

                if priorOp != nil {
                    op.addDependency(priorOp!)
                }

                priorOp               = op
                operations[syncState] = op
                
                queue.addOperation(op)
            }
        }

        isReady           = false;
        queue.isSuspended = false
    }


    func invokeOn(_ state: ZSynchronizationState) {
        let operation = operations[state]!

        print(state)

        switch(state) {
        case .restore:     zfileManager.restore();        operation.finish();   break
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

        if onReady != nil {
            onReady!()

            onReady = nil
        }

        operation.finish()
    }
}
