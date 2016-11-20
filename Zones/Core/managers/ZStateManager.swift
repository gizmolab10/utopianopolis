//
//  ZStateManager.swift
//  Zones
//
//  Created by Jonathan Sand on 10/14/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZStateManager: NSObject {


    var         isReady:                                   Bool = false
    var   textCapturing:                                   Bool = false
    var       toolState:                              ZToolMode = .edit
    var      operations: [ZSynchronizationState:BlockOperation] = [:]
    let           queue:                         OperationQueue = OperationQueue()
    let   genericOffset:                                 CGSize = CGSize(width: 0.0, height: 4.0)
    let       lineColor:                                 ZColor = ZColor.purple //(hue: 0.6, saturation: 0.6, brightness: 1.0,                alpha: 1)
    let unselectedColor:                                 ZColor = ZColor(hue: 0.6, saturation: 0.0, brightness: unselectBrightness, alpha: 1)
    let    lineThicknes:                                CGFloat = 1.25
    let       dotLength:                                CGFloat = 12.0


    var lightFillColor: ZColor { get { return lineColor.withAlphaComponent(0.03) } }


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
        case .root:        cloudManager.setupRootWith      (operation:operation); break
        case .fetch:       cloudManager.fetchOnCompletion { operation.finish() }; break
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
