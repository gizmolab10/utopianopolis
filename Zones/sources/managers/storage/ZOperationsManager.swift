//
//  ZOperationsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation


enum ZOperationID: Int {
    case onboard
    case cloud
    case root
    case file
    case manifest   // zones which show children
    case here
    case children
    case fetch      // after children so favorite targets resolve properly
    case parent     // after fetch so colors resolve properly
    case save       // zones and manifests
    case unsubscribe
    case subscribe

    /////////////////////////////////////////////////////////////////////
    // the following do not participate in startup, finish up, or sync //
    /////////////////////////////////////////////////////////////////////

    case emptyTrash
    case completion
    case bookmarks
    case undelete
    case create
    case merge
    case trash
    case none

    /////////////////////////////////////////
    // the following constitute onboarding //
    /////////////////////////////////////////

    case internet
    case ubiquity
    case accountStatus      // vs no account
    case fetchUserID
    case fetchUserRecord    // record
    case fetchUserIdentity
}


class ZOperationsManager: NSObject {


    var queue = OperationQueue()


    func setupAndRunUnsafe(_ operationIDs: [ZOperationID], logic: ZRecursionLogic?, onCompletion: @escaping Closure) {}


    func setupAndRun(_ operationIDs: [ZOperationID], logic: ZRecursionLogic? = nil, onCompletion: @escaping Closure) {
        FOREGROUND(canBeDirect: true) {
            self.setupAndRunUnsafe(operationIDs, logic: logic, onCompletion: onCompletion)
        }
    }


    func setupAndRunOps(from: ZOperationID, to: ZOperationID, _ onCompletion: @escaping Closure) {
        var operationIDs = [ZOperationID] ()

        for sync in from.rawValue...to.rawValue {
            operationIDs.append(ZOperationID(rawValue: sync)!)
        }

        setupAndRun(operationIDs) { onCompletion() }
    }


    func add(_ operation: BlockOperation) {
        if let prior = queue.operations.last {
            operation.addDependency(prior)
        } else {
            queue.qualityOfService            = .background
            queue.maxConcurrentOperationCount = 1
        }

        queue.addOperation(operation)
    }

}
