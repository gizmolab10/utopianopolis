//
//  ZOperations.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import SystemConfiguration.SCNetworkConnection

enum ZOperationID: Int {

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
    case oFound              // LOCAL
    case oFavorites
    case oRoots
    case oHere
	case oStartupDone

    // finish

    case oFinishUp
	case oNewZones
	case oSubscribe
	case oAllZones
	case oAllTraits
	case oRecount
    case oDone

    // miscellaneous

	case oFetchAndMerge
	case oFetchNeeded        // after children so favorite targets resolve properly
    case oSaveToCloud        // zones, traits, destroy
    case oEmptyTrash
    case oCompletion
    case oBookmarks
    case oFetchLost
    case oUndelete
    case oChildren
    case oParents            // after fetch so colors resolve properly
    case oRefetch            // user defaults list of record ids
    case oTraits
    case oNone               // default operation

    var isLocal     : Bool { return localOperations.contains(self) }
    var isDeprecated: Bool { return   deprecatedOps.contains(self) }
	var isDone      : Bool { return         doneOps.contains(self) }

	var description : String { return "\(self)".substring(fromInclusive: 1).unCamelcased }
}

let	        doneOps : [ZOperationID] = [.oNone, .oDone, .oCompletion]
let   deprecatedOps : [ZOperationID] = [.oParents]
let localOperations : [ZOperationID] = [.oHere, .oRoots, .oFound, .oReadFile, .oInternet, .oUbiquity, .oFavorites, .oCompletion,
										.oMacAddress, .oFetchUserID, .oObserveUbiquity, .oFetchUserRecord, .oCheckAvailability]

class ZOperations: NSObject {

	let            queue = OperationQueue()
	var        currentOp :  ZOperationID  =  .oNone
	var hiddenSpinnerOps : [ZOperationID] = [.oAllZones, .oTraits, .oSaveToCloud]
	var     shouldCancel :          Bool  { return !currentOp.isDone && -(negativeTimeSinceOpStart ?? 0.0) > 5.0 }
	var    debugTimeText :        String  { return "\(Double(gDeciSecondsSinceLaunch) / 10.0)" }
    var  onCloudResponse :    AnyClosure?
	var        cloudFire :  TimerClosure?
    var      lastOpStart :        NSDate?
	func printOp(_ message: String) { columnarReport(mode: .dOps, operationText, message) }

    var operationText: String {
        var s = String(describing: currentOp)
        s     = s.substring(fromInclusive: 1)
        let c = s.substring(  toExclusive: 1).lowercased()
        s     = s.substring(fromInclusive: 1)

        return c + s
    }
    
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

    func unHang() { onCloudResponse?(0) }

    @discardableResult func cloudStatusChanged() -> Bool {
        let          hasInternet = isConnectedToNetwork
        let       changedConnect =              hasInternet != gHasInternet
        let       changedAccount = recentCloudAccountStatus != gCloudAccountStatus
        gHasInternet             = hasInternet
        recentCloudAccountStatus = gCloudAccountStatus

        return changedConnect || changedAccount
    }

    func setupCloudTimer() {
        if  cloudFire == nil {
            cloudFire  = { iTimer in
                FOREGROUND(canBeDirect: true) {
                    if  self.shouldCancel {
                        gBatches.unHang()
                    }
                    
                    if  self.cloudStatusChanged() {
                        self.signal([.sStatus]) // show change in cloud status

                        // //////////////////////////////////////////////
                        // assure that we can perform cloud operations //
                        // //////////////////////////////////////////////

                        if  gHasInternet && gIsReadyToShowUI {
                            let identifier: ZBatchID = gCanAccessMyCloudDatabase ? .bResumeCloud : .bNewAppleID

                            gBatches.batch(identifier) { iResult in
                                if  gCanAccessMyCloudDatabase {
                                    gFavorites.updateAllFavorites()
                                }

                                self.redrawGraph()
                            }
                        }
                    }
                }
            }

			gTimers.setTimer(for: .tCloudAvailable, withTimeInterval: 0.2, repeats: true, block: cloudFire!)
            cloudFire?(nil)
        }
    }

    func invokeOperation(for identifier: ZOperationID, cloudCallback: AnyClosure?) {}
    func invokeMultiple (for identifier: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping BooleanClosure) {}

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

                if  operationID.isLocal || gCanAccessMyCloudDatabase {

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
							self.signal([.sStatus]) // show change in cloud status

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
			signal([.sStatus]) // show change in cloud status
        }

        queue.isSuspended = false
    }

    func reportBeforePerformBlock() {
		if !gHasFinishedStartup {
			printOp(debugTimeText)
		}
	}

    var negativeTimeSinceOpStart: TimeInterval? {
        return lastOpStart?.timeIntervalSinceNow
    }

    func reportOnCompletionOfPerformBlock() {
		if  gHasFinishedStartup,
			let negative = negativeTimeSinceOpStart {
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
