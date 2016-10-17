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
    case select
    case restore
    case root
    case unsubscribe
    case subscribe
    case ready
}


class ZBlockOperation: BlockOperation {


    func done() {
        willChangeValue(forKey: "isFinished");

        completed = true

        didChangeValue (forKey: "isFinished");
    }


    var completed: Bool = false;
    override var isFinished: Bool {
        get { return super.isFinished && completed }
    }
}


let stateManager: ZStateManager = ZStateManager()


class ZStateManager: NSObject {


    var operations: [ZSynchronizationState:ZBlockOperation] = [:]
    var  toolState:                              ZToolState = .edit
    let      queue:                          OperationQueue = OperationQueue()


    func setupAndRun() {
        setup()

        queue.isSuspended = false
    }


    func setup() {
        queue.isSuspended = true
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .background
        let allRawStates = ZSynchronizationState.select.rawValue...ZSynchronizationState.ready.rawValue
        var priorOp: BlockOperation? = nil
        for sync in allRawStates {
            let state: ZSynchronizationState = ZSynchronizationState(rawValue: sync)!
            let op = ZBlockOperation { self.invokeOn(state) }

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
        case .select:      modelManager.setupWith    (operation:operation); break
        case .restore:     persistenceManager.restore();  operation.done(); break
        case .root:        modelManager.setupRootZone();  operation.done(); break
        case .unsubscribe: modelManager.registerWith (operation:operation); break
        case .subscribe:   modelManager.subscribeWith(operation:operation); break
        case .ready:                                      operation.done(); break
        }
    }
}
