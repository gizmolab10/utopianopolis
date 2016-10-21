//
//  ZStateManager.swift
//  Zones
//
//  Created by Jonathan Sand on 10/14/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


enum ZToolState: Int {
    case edit
    case travel
    case layout
}


enum ZSynchronizationState: Int {
    case restore
    case root
    case unsubscribe
    case subscribe
    case ready
}


let stateManager: ZStateManager = ZStateManager()


class ZStateManager: NSObject {


    var    isReady:                                   Bool = false
    var  toolState:                             ZToolState = .edit
    var operations: [ZSynchronizationState:BlockOperation] = [:]
    let      queue:                         OperationQueue = OperationQueue()


    func setupAndRun() {
        setup()

        queue.isSuspended = false
    }


    func setup() {
        queue.isSuspended = true
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .background
        let allRawStates = ZSynchronizationState.restore.rawValue...ZSynchronizationState.ready.rawValue
        var priorOp: BlockOperation? = nil
        for sync in allRawStates {
            let state: ZSynchronizationState = ZSynchronizationState(rawValue: sync)!
            let op = BlockOperation { self.invokeOn(state) }

            if priorOp != nil {
                op.addDependency(priorOp!)
            }

            priorOp           = op
            operations[state] = op

            queue.addOperation(op)
        }
    }


    func invokeOn(_ state: ZSynchronizationState) {
        let operation = operations[state]!

        print(state)

        switch(state) {
        case .restore:     persistenceManager.restore();   operation.finish(); break
        case .root:        modelManager.setupRootZone();   operation.finish(); break
        case .unsubscribe: modelManager.unsubscribeWith (operation:operation); break
        case .subscribe:   modelManager.subscribeWith   (operation:operation); break
        case .ready:       isReady = true;                 operation.finish(); break
        }
    }
}
