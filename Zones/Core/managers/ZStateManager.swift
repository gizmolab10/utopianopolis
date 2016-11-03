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
    var       toolState:                              ZToolMode = .edit
    var      operations: [ZSynchronizationState:BlockOperation] = [:]
    let           queue:                         OperationQueue = OperationQueue()
    let   genericOffset:                                 CGSize = CGSize(width: 0.0, height: 6.0)
    let       lineColor:                                 ZColor = ZColor(hue: 0.6, saturation: 0.6, brightness: 1.0,                alpha: 1)
    let unselectedColor:                                 ZColor = ZColor(hue: 0.6, saturation: 0.0, brightness: unselectBrightness, alpha: 1)
    let    lineThicknes:                                CGFloat = 1.25
    let       dotLength:                                CGFloat = 12.0


    func setupAndRun() {
        synchronize()

        queue.isSuspended = false
    }


    func synchronize() {
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
        case .root:        cloudManager.setupRootWith   (operation:operation); break
        case .unsubscribe: cloudManager.unsubscribeWith (operation:operation); break
        case .subscribe:   cloudManager.subscribeWith   (operation:operation); break
        case .ready:       isReady = true;                 operation.finish(); break
        }
    }
}
