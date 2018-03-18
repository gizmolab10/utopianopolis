//
//  ZOperationsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import SystemConfiguration.SCNetworkConnection


enum ZOperationID: Int {

    // onboard

    case observeUbiquity
    case accountStatus      // vs no account
    case fetchUserID
    case internet
    case ubiquity
    case fetchUserRecord

    // startup

    case cloud
    case read               // LOCAL
    case found              // LOCAL
    case save               // zones, traits, destroy
    case root
    case favorites

    // continue

    case here
    case fetchNew
    case fetchAll

    // finish

    case write              // LOCAL
    case unsubscribe
    case subscribe

    // miscellaneous

    case emptyTrash
    case completion
    case fetchlost
    case bookmarks
    case undelete
    case children
    case parents            // after fetch so colors resolve properly
    case refetch            // user defaults list of record ids
    case onboard            // LOCAL (partially)
    case traits
    case fetch              // after children so favorite targets resolve properly
    case merge
    case none               // default operation
}


var gDebugTimerCount          = 0
var gDebugTimer:       Timer? = nil
var gCloudTimer:       Timer? = nil
var gCloudFire: TimerClosure? = nil
var gHasInternet              = true
var gCloudAccountStatus       = ZCloudAccountStatus.begin
var recentCloudAccountStatus  = gCloudAccountStatus


class ZOperationsManager: NSObject {


    var   operationText :       String  { return String(describing: currentOp) }
    var onCloudResponse :   AnyClosure? = nil
    var     lastOpStart :         Date? = nil
    var       currentOp = ZOperationID.none
    let           queue = OperationQueue()


    var isConnectedToNetwork: Bool {
        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)

        if let host = SCNetworkReachabilityCreateWithName(nil, "www.apple.com"),
            !SCNetworkReachabilityGetFlags(host, &flags) {
            return false
        }

        let     isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)

        return isReachable && !needsConnection
    }


    var usingDebugTimer: Bool {
        get { return gDebugTimer?.isValid ?? false }
        set {
            let fire: TimerClosure = { iTimer in
                if gDebugTimerCount % 10 == 0 || gDebugTimer?.isValid == false {
                   // self.columnarReport("---- TIME ----", "\(Float(gDebugTimerCount) / 10.0) -----------")
                }

                gDebugTimerCount += 1
            }

            if  gMeasureOpsPerformance && newValue {
                gDebugTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: fire)
                fire(gDebugTimer!)
            } else if gDebugTimer != nil && !newValue {
                gDebugTimer?.invalidate()
                fire(gDebugTimer!)
            }
        }
    }


    func     unHang()                                  {                                                                                                  onCloudResponse?(0) }
    func    startUp(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .observeUbiquity, to: .fetchAll,                                            onCompletion) }
    func   finishUp(_ onCompletion: @escaping Closure) { setupAndRunOps(from: .write,           to: .subscribe,                                           onCompletion) }
    func emptyTrash(_ onCompletion: @escaping Closure) { setupAndRun([.emptyTrash                                                                    ]) { onCompletion() } }
    func  fetchLost(_ onCompletion: @escaping Closure) { setupAndRun([.fetchlost,                           .save, .children                         ]) { onCompletion() } }
    func newAppleID(_ onCompletion: @escaping Closure) { setupAndRun([.onboard,   .read,                    .root, .fetchNew,                  .write]) { onCompletion() } }
    func   pOldSync(_ onCompletion: @escaping Closure) { setupAndRun([            .fetch, .parents, .merge, .save, .children,         .traits, .write]) { onCompletion() } }
    func      pSave(_ onCompletion: @escaping Closure) { setupAndRun([                                      .save,                             .write]) { onCompletion() } }
    func      pSync(_ onCompletion: @escaping Closure) { setupAndRun([            .fetch,           .merge, .save,                             .write]) { onCompletion() } }
    func      pRoot(_ onCompletion: @escaping Closure) { setupAndRun([.root,                                .save, .children,         .traits        ]) { onCompletion() } }
    func    pTravel(_ onCompletion: @escaping Closure) { setupAndRun([.root,              .parents,                .children, .fetch, .traits        ]) { onCompletion() } }
    func   pParents(_ onCompletion: @escaping Closure) { setupAndRun([                    .parents,                                   .traits        ]) { onCompletion() } }
    func  pFamilies(_ onCompletion: @escaping Closure) { setupAndRun([            .fetch, .parents,                .children,         .traits        ]) { onCompletion() } }
    func pBookmarks(_ onCompletion: @escaping Closure) { setupAndRun([.bookmarks, .fetch,                   .save,                    .traits        ]) { onCompletion() } }
    func  pChildren(_ onCompletion: @escaping Closure) { setupAndRun([                                             .children,         .traits        ]) { onCompletion() } }
    func   undelete(_ onCompletion: @escaping Closure) { setupAndRun([.undelete,  .fetch, .parents,         .save, .children,         .traits        ]) { onCompletion() } }


    func updateCloudStatus(_ onCompletion: BooleanClosure?) {
        let          hasInternet = isConnectedToNetwork
        let      changedInternet =              hasInternet != gHasInternet
        let      changedUser     = recentCloudAccountStatus != gCloudAccountStatus
        gHasInternet             = hasInternet
        recentCloudAccountStatus = gCloudAccountStatus

        onCompletion?(changedInternet || changedUser)
    }


    func setupCloudTimer() {
        if  gCloudTimer == nil {
            gCloudFire   = { iTimer in
                FOREGROUND {
                    self.updateCloudStatus { iChangeHappened in
                        if  iChangeHappened {
                            self.signalFor(nil, regarding: .information) // inform user of change in cloud status

                            /////////////////////////////////////////////////
                            // assure that we can perform cloud operations //
                            /////////////////////////////////////////////////

                            if  gHasInternet && gCloudAccountStatus != .active && gIsReadyToShowUI {
                                self.setupAndRunOps(from: .internet, to: .fetchUserRecord) {
                                    self.signalFor(nil, regarding: .redraw)
                                }
                            }
                        }
                    }
                }
            }

            gCloudTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: gCloudFire!)
            gCloudFire?(gCloudTimer!)
        }
    }


    func invoke(_ identifier: ZOperationID, cloudCallback: AnyClosure?) {}
    func performBlock(for operationID: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping BooleanClosure) {}


    func shouldIgnoreOperation(_ iID: ZOperationID) -> Bool {
        switch iID {
        case .read, .write, .found, .observeUbiquity, .accountStatus, .fetchUserID, .internet, .ubiquity, .completion: return false
     //   case .fetchUserRecord:                                                                                         return gCloudAccountStatus.rawValue < ZCloudAccountStatus.available.rawValue
        default:                                                                                                       return !gHasInternet
        }
    }


    func setupAndRunUnsafe(_ operationIDs: [ZOperationID], onCompletion: @escaping Closure) {
        setupCloudTimer()

        if queue.operationCount > 1500 {
            gAlertManager.alertWith("overloading queue", "programmer error", "send an email to sand@gizmolab.com") { iObject in
               // onCompletion()
            }
        }

        queue.isSuspended = true
        let         saved = gDatabaseID

        for operationID in operationIDs + [.completion] {
            let blockOperation = BlockOperation {
                if !self.shouldIgnoreOperation(operationID) {

                    //////////////////////////////////////////////////////////////////
                    // susend queue until operation function calls its onCompletion //
                    //////////////////////////////////////////////////////////////////

                    self.queue.isSuspended = true
                    let              start = Date()
                    self.currentOp         = operationID        // if hung, it happened inside this op

                    self.reportBeforePerformBlock()

                    self.performBlock(for: operationID, restoreToID: saved) { iResult in
                        self.reportOnCompletionOfPerformBlock(start)        // says nothing

                        FOREGROUND {
                            if self.currentOp == .completion {

                                //////////////////////////////////////
                                // done with this set of operations //
                                //////////////////////////////////////

                                onCompletion()
                            }

                            ////////////////////////
                            // release suspension //
                            ////////////////////////

                            self.queue.isSuspended = false
                        }
                    }
                }
            }

            add(blockOperation)
        }

        queue.isSuspended = false
    }


    func reportBeforePerformBlock() {
        if  gMeasureOpsPerformance {
            let timeText = !self.usingDebugTimer ? "" : "\(Float(gDebugTimerCount) / 10.0)"

            self.columnarReport("  " + self.operationText, timeText)
        }
    }


    func reportOnCompletionOfPerformBlock(_ start: Date) {
        if  gMeasureOpsPerformance && false {
            let   duration = Int(start.timeIntervalSinceNow) * -10
            let    message = "\(Float(duration) / 10.0)"

            self.columnarReport("  " + self.operationText, message)
        }
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
