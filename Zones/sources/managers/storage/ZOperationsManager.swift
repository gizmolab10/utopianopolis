//
//  ZOperationsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation


enum ZOperationID: Int {

    // startup

    case onboard
    case cloud
    case read
    case found
    case save               // zones, traits, destroy
    case root

    // continue

    case here
    case fetchNew

    // finish

    case write
    case unsubscribe
    case subscribe

    // onboarding

    case setup
    case accountStatus      // vs no account
    case fetchUserID
    case internet
    case ubiquity
    case fetchUserRecord
    case fetchUserIdentity

    // miscellaneous

    case emptyTrash
    case completion
    case fetchlost
    case bookmarks
    case undelete
    case children
    case parents            // after fetch so colors resolve properly
    case refetch            // user defaults list of record ids
    case traits
    case fetch              // after children so favorite targets resolve properly
    case merge
    case none               // default operation
}


class ZOperationsManager: NSObject {


    var   operationText :       String  { return String(describing: currentOp) }
    var onCloudResponse :   AnyClosure? = nil
    var     lastOpStart :         Date? = nil
    var       currentOp = ZOperationID.none
    let           queue = OperationQueue()


    func invoke(_ identifier: ZOperationID, cloudCallback: AnyClosure?) {}
    func performBlock(for operationID: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping Closure) {}


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


    func shouldPerform(_ iID: ZOperationID) -> Bool {
        let cloudFetch = gFetchMode != .localOnly
        let cloudSave  =  gSaveMode != .localOnly
        var yesPerform = true

        switch iID {
        case .save:                                                                                                                            yesPerform = cloudSave
        case .fetch, .merge, .traits, .emptyTrash, .fetchlost, .undelete, .refetch, .parents, .children, .bookmarks, .subscribe, .unsubscribe: yesPerform = cloudFetch && !gAssumeAllFetched
        case .cloud, .internet, .ubiquity, .fetchUserRecord, .fetchUserIdentity:                                                               yesPerform = cloudFetch || cloudSave
        default: break
        }

        return yesPerform
    }


    func setupAndRunUnsafe(_ operationIDs: [ZOperationID], onCompletion: @escaping Closure) {
        if gIsLate {
            FOREGROUND { // avoid stack overflow
                onCompletion()
            }
        }

        if queue.operationCount > 1500 {
            gAlertManager.alertWith("overloading queue", "programmer error", "send an email to sand@gizmolab.com") { iObject in
               // onCompletion()
            }
        }

        queue.isSuspended = true
        let         saved = gDatabaseID

        for operationID in operationIDs + [.completion] {
            if shouldPerform(operationID) {
                let         blockOperation = BlockOperation {
                    self.queue.isSuspended = true
                    let              start = Date()

                    FOREGROUND {
                        self.currentOp     = operationID        // if hung, it happened inside this op

                        if  gDebugOperations {
                            let    message = !self.usingDebugTimer ? "" : "\(Float(gDebugTimerCount) / 10.0)"

                            self.columnarReport("  " + self.operationText, message)
                        }

                        self.performBlock(for: operationID, restoreToID: saved) {
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
        }

        queue.isSuspended = false
    }


    func setupAndRun(_ operationIDs: [ZOperationID], onCompletion: @escaping Closure) {
        FOREGROUND(canBeDirect: true) {
            self.setupAndRunUnsafe(operationIDs, onCompletion: onCompletion)
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
