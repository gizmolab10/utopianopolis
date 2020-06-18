//
//  ZOperations.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import SystemConfiguration.SCNetworkConnection

enum ZOperationID: Int {

	case oNone               // default operation does nothing

    // onboard

    case oStartUp            // NB: order here is order of operations (except miscellaneous)
    case oMacAddress
    case oObserveUbiquity
    case oCheckAvailability  // vs no account
    case oInternet
    case oUbiquity
    case oFetchUserID
    case oFetchUserRecord

    // continue

    case oCloud
    case oManifest
    case oReadFile           // LOCAL
    case oFoundIdeas         // LOCAL
	case oFavorites
	case oRecents
	case oRoots
    case oHere
	case oStartupDone

    // finish

    case oFinishUp
	case oNewIdeas
	case oSubscribe
	case oAllIdeas
	case oAllTraits
	case oRecount
    case oDone

    // miscellaneous

	case oFetchAndMerge
	case oNeededIdeas        // after children so favorite targets resolve properly
    case oSaveToCloud        // zones, traits, destroy
	case oParentIdeas        // after fetch so colors resolve properly
	case oChildIdeas
    case oEmptyTrash
    case oCompletion
    case oBookmarks
    case oLostIdeas
    case oUndelete
    case oRefetch            // user defaults list of record ids
    case oTraits

    var isLocal     : Bool { return localOperations.contains(self) }
    var isDeprecated: Bool { return   deprecatedOps.contains(self) }
	var isDone      : Bool { return         doneOps.contains(self) }

	var description : String { return "\(self)".substring(fromInclusive: 1).unCamelcased }
}

let	        doneOps : [ZOperationID] = [.oNone, .oDone, .oCompletion]
let   deprecatedOps : [ZOperationID] = [.oParentIdeas]
let localOperations : [ZOperationID] = [.oHere, .oRoots, .oFoundIdeas, .oReadFile, .oInternet, .oUbiquity, .oFavorites, .oCompletion,
										.oMacAddress, .oFetchUserID, .oObserveUbiquity, .oFetchUserRecord, .oCheckAvailability]

class ZOperations: NSObject {

	let             queue = OperationQueue()
	var         currentOp :  ZOperationID  = .oNone
	var      shouldCancel :          Bool  { return !currentOp.isDone && -(inverseOpDuration ?? 0.0) > 5.0 }
	var     debugTimeText :        String  { return "\(Double(gDeciSecondsSinceLaunch) / 10.0)" }
	var inverseOpDuration :  TimeInterval? { return lastOpStart?.timeIntervalSinceNow }
	var         cloudFire :  TimerClosure?
	var   onCloudResponse :    AnyClosure?
    var       lastOpStart :        NSDate?
	func printOp(_ message: String)        { columnarReport(mode: .dOps, operationText, message) }
	func unHang()                          { onCloudResponse?(0) }
	func invokeOperation(for identifier: ZOperationID, cloudCallback: AnyClosure?)                                         {}
	func invokeMultiple (for identifier: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping BooleanClosure) {}

    var operationText: String {
        var s = String(describing: currentOp)
        s     = s.substring(fromInclusive: 1)
        let c = s.substring(  toExclusive: 1).lowercased()
        s     = s.substring(fromInclusive: 1)

        return c + s
    }
    
    var isConnectedToInternet: Bool {
        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)

        if let host = SCNetworkReachabilityCreateWithName(nil, "www.apple.com"),
            !SCNetworkReachabilityGetFlags(host, &flags) {
            return false
        }

        let     isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)

        return isReachable && !needsConnection
    }

    @discardableResult func cloudStatusChanged() -> Bool {
        let          hasInternet = isConnectedToInternet
        let     changedConnected =              hasInternet != gHasInternet
        let     changedStatus    = recentCloudAccountStatus != gCloudAccountStatus
        gHasInternet             = hasInternet
        recentCloudAccountStatus = gCloudAccountStatus

        return changedConnected || changedStatus
    }

    func setupCloudTimer() {
        if  cloudFire == nil {
            cloudFire  = { iTimer in
                FOREGROUND(canBeDirect: true) {
                    if  self.shouldCancel {
                        gBatches.unHang()
                    }
                    
                    if  self.cloudStatusChanged() {
                        gSignal([.sStatus]) // show change in cloud status

                        // //////////////////////////////////////////////
                        // assure that we can perform cloud operations //
                        // //////////////////////////////////////////////

                        if  gHasInternet && gIsReadyToShowUI {
                            let identifier: ZBatchID = gCloudStatusIsActive ? .bResumeCloud : .bNewAppleID

                            gBatches.batch(identifier) { iResult in
                                if  gCloudStatusIsActive {
                                    gFavorites.updateAllFavorites()
                                }

                                gRedrawGraph()
                            }
                        }
                    }
                }
            }

			cloudFire?(nil)
			gTimers.resetTimer(for: .tCloudAvailable, withTimeInterval:  0.2, repeats: true, block: cloudFire!)
			gTimers.resetTimer(for: .tSync,           withTimeInterval: 15.0, repeats: true) { iTimer in
				if  gIsReadyToShowUI {
					gBatches.sync { iSame in

					}
				}
			}
        }
    }

    func setupAndRun(_ operationIDs: [ZOperationID], onCompletion: @escaping Closure) {
        setupCloudTimer()

        if  queue.operationCount > 10 {
            gAlerts.showAlert("overloading queue", "programmer error", "send an email to sand@gizmolab.com") { iObject in
               // onCompletion()
            }
        }

        queue.isSuspended = true
        let         saved = gDatabaseID

        for operationID in operationIDs + [.oCompletion] {
            if  operationID.isDeprecated { continue }

            let blockOperation = BlockOperation {

                // /////////////////////////////////////////////////////////////
                // ignore operations that are not local when have no internet //
                // /////////////////////////////////////////////////////////////

                if  operationID.isLocal || gCloudStatusIsActive {

                    // ///////////////////////////////////////////////////////////////
                    // susend queue until operation function calls its onCompletion //
                    // ///////////////////////////////////////////////////////////////

                    self.queue.isSuspended = true
					self.lastOpStart       = NSDate()
                    self.currentOp         = operationID        // if hung, it happened inside this op

                    self.reportBeforePerformBlock()

                    self.invokeMultiple(for: operationID, restoreToID: saved) { iResult in
                        self.reportOnCompletionOfPerformBlock()

                        FOREGROUND {
							gSignal([.sStatus, .sStartup]) // show change in cloud status and startup progress

							if  self.currentOp == .oCompletion {

                                // /////////////////////////////////////
                                // done with this batch of operations //
								// /////////////////////////////////////

                                onCompletion()
                            }

							// /////////////////////
                            // release suspension //
							// /////////////////////

                            self.queue.isSuspended = false
                        }
                    }
                }
            }

            add(blockOperation)
			gSignal([.sStatus]) // show change in cloud status
        }

        queue.isSuspended = false
    }

    func reportBeforePerformBlock() {
		if !gHasFinishedStartup {
			printOp(debugTimeText)
		}
	}

    func reportOnCompletionOfPerformBlock() {
		if  gHasFinishedStartup,
			let negative = inverseOpDuration {
            let duration = Float(Int(negative * -10)) / 10.0 // round to nearest tenth of second

            printOp("\(duration)")
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