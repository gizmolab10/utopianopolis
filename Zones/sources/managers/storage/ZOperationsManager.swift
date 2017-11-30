//
//  ZOperationsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation


enum ZOperationID: Int {

    ///////////////////////////////////////////////////////////////////////
    // the following operations constitute all of startup, in this order //
    ///////////////////////////////////////////////////////////////////////

    case onboard
    case cloud
    case root
    case file
    case refetch    // user defaults list of record ids
    case manifest   // zones which show children
    case here       // needs manifest
    case children
    case fetch      // after children so favorite targets resolve properly
    case parent     // after fetch so colors resolve properly
    case save       // zones and manifests
    case bookmarks
    case remember
    case unsubscribe
    case subscribe

    /////////////////////////////////////////
    // the following constitute onboarding //
    /////////////////////////////////////////

    case setup
    case internet
    case ubiquity
    case accountStatus      // vs no account
    case fetchUserID
    case fetchUserRecord    // record
    case fetchUserIdentity

    ///////////////////////////////////////////////////////////////
    // the following do not participate in startup or onboarding //
    ///////////////////////////////////////////////////////////////

    case emptyTrash
    case completion
    case undelete
    case merge
    case trash
    case none // default operation
}


var gDebugTimer : Timer? = nil
var gDebugTimerCount : Int = 0
var gDebugOperations = false


class ZOperationsManager: NSObject {


    var   operationText :       String  { return String(describing: currentOp) }
    var onCloudResponse :   AnyClosure? = nil
    var     lastOpStart :         Date? = nil
    var       currentOp = ZOperationID.none
    let           queue = OperationQueue()


    func invoke(_ identifier: ZOperationID, _ logic: ZRecursionLogic? = nil, cloudCallback: AnyClosure?) {}
    func performBlock(for operationID: ZOperationID, with logic: ZRecursionLogic? = nil, restoreToMode: ZStorageMode, _ onCompletion: @escaping Closure) {}


    var usingDebugTimer: Bool {
        get { return gDebugTimer?.isValid ?? false }
        set {
            let fire: TimerClosure = { iTimer in
                if gDebugTimerCount % 10 == 0 || gDebugTimer?.isValid == false {
                   // self.columnarReport("---- TIME ----", "\(Float(gDebugTimerCount) / 10.0) -----------")
                }

                gDebugTimerCount += 1
            }

            if  gDebugOperations && newValue {
                gDebugTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: fire)
                fire(gDebugTimer!)
            } else if gDebugTimer != nil && !newValue {
                gDebugTimer?.invalidate()
                fire(gDebugTimer!)
            }
        }
    }


    func setupAndRunUnsafe(_ operationIDs: [ZOperationID], logic: ZRecursionLogic?, onCompletion: @escaping Closure) {
        if gIsLate {
            onCompletion()
        }

        queue.isSuspended = true
        let         saved = gStorageMode

        for operationID in operationIDs + [.completion] {
            let         blockOperation = BlockOperation {
                self.queue.isSuspended = true
                let              start = Date()

                FOREGROUND {
                    self.currentOp     = operationID        // if hung, it happened inside this op

                    if  gDebugOperations {
                        let    message = !self.usingDebugTimer ? "" : "\(Float(gDebugTimerCount) / 10.0)"

                        self.columnarReport("  " + self.operationText, message)
                    }

                    self.performBlock(for: operationID, with: logic, restoreToMode: saved) {
                        if  gDebugOperations && false {
                            let   duration = Int(start.timeIntervalSinceNow) * -10
                            let    message = "\(Float(duration) / 10.0)"

                            self.columnarReport("  " + self.operationText, message)
                        }
                        
                        if self.currentOp == .completion {
                            onCompletion()
                        }
                    }
                }
            }

            add(blockOperation)
        }

        queue.isSuspended = false
    }


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
