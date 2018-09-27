//
//  ZOperationsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import SystemConfiguration.SCNetworkConnection


typealias TimerClosure = (Timer?) -> (Void)


enum ZOperationID: Int {

    // onboard

    case macAddress
    case observeUbiquity
    case checkAvailability  // vs no account
    case internet
    case ubiquity
    case fetchUserID
    case fetchUserRecord

    // startup

    case cloud
    case readThoughtful     // LOCAL
    case found              // LOCAL
    case roots
    case favorites
    case here
    case fetchNew
    case fetchAll

    // finish

    case save               // zones, traits, destroy
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
    case traits
    case fetch              // after children so favorite targets resolve properly
    case merge
    case none               // default operation

    var isLocal: Bool { return localOperations.contains(self) }

}


let localOperations: [ZOperationID] = [.here, .roots, .found, .internet, .ubiquity, .favorites, .completion, .macAddress, .fetchUserID, .observeUbiquity, .readThoughtful, .fetchUserRecord, .checkAvailability]


var gDebugTimerCount          = 0
var gDebugTimer:       Timer? = nil
var gCloudTimer:       Timer? = nil
var gCloudFire: TimerClosure? = nil
var gHasInternet              = true
var gCloudAccountStatus       = ZCloudAccountStatus.begin
var gCloudAccountIsActive     = gCloudAccountStatus == .active
var recentCloudAccountStatus  = gCloudAccountStatus


class ZOperationsManager: NSObject {


    var   debugTimeText :       String  { return !usingDebugTimer ? "" : "\(Float(gDebugTimerCount) / 10.0)" }
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
                fire(nil)
            } else if gDebugTimer != nil && !newValue {
                gDebugTimer?.invalidate()
                fire(nil)
            }
        }
    }


    func unHang() { onCloudResponse?(0) }


    @discardableResult func checkCloudStatus() -> Bool {
        let          hasInternet = isConnectedToNetwork
        let       changedConnect =              hasInternet != gHasInternet
        let       changedAccount = recentCloudAccountStatus != gCloudAccountStatus
        gHasInternet             = hasInternet
        recentCloudAccountStatus = gCloudAccountStatus

        return changedConnect || changedAccount
    }


    func setupCloudTimer() {
        if  gCloudTimer == nil {
            gCloudFire   = { iTimer in
                FOREGROUND {
                    if  self.checkCloudStatus() {
                        self.signalFor(nil, regarding: .information) // inform user of change in cloud status

                        /////////////////////////////////////////////////
                        // assure that we can perform cloud operations //
                        /////////////////////////////////////////////////

                        if  gHasInternet && gIsReadyToShowUI {
                            let identifier: ZBatchID = gCloudAccountIsActive ? .resumeCloud : .newAppleID

                            gBatchManager.batch(identifier) { iResult in
                                if  gCloudAccountIsActive {
                                    gFavoritesManager.updateFavorites()
                                }

                                self.signalFor(nil, regarding: .redraw)
                            }
                        }
                    }
                }
            }

            gCloudTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: gCloudFire!)
            gCloudFire?(nil)
        }
    }


    func invokeOperation(for identifier: ZOperationID, cloudCallback: AnyClosure?) {}
    func invokeMultiple (for identifier: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping BooleanClosure) {}


    func setupAndRun(_ operationIDs: [ZOperationID], onCompletion: @escaping Closure) {
        setupCloudTimer()

        if queue.operationCount > 10 {
            gAlertManager.showAlert("overloading queue", "programmer error", "send an email to sand@gizmolab.com") { iObject in
               // onCompletion()
            }
        }

        queue.isSuspended = true
        let         saved = gDatabaseID

        for operationID in operationIDs + [.completion] {
            let blockOperation = BlockOperation {

                ////////////////////////////////////////////////////////////////
                // ignore operations that are not local when have no internet //
                ////////////////////////////////////////////////////////////////

                if  operationID.isLocal || gCloudAccountIsActive {

                    //////////////////////////////////////////////////////////////////
                    // susend queue until operation function calls its onCompletion //
                    //////////////////////////////////////////////////////////////////

                    self.queue.isSuspended = true
                    let              start = Date()
                    self.currentOp         = operationID        // if hung, it happened inside this op

                    self.reportBeforePerformBlock()

                    self.invokeMultiple(for: operationID, restoreToID: saved) { iResult in
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
            columnarReport("  " + operationText, debugTimeText)
        }
    }


    func reportOnCompletionOfPerformBlock(_ start: Date) {
        if  gMeasureOpsPerformance && false {
            let   duration = Int(start.timeIntervalSinceNow) * -10
            let    message = "\(Float(duration) / 10.0)"

            columnarReport("  " + operationText, message)
        }
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
