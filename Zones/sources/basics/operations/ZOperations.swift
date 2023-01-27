//
//  ZOperations.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import SystemConfiguration.SCNetworkConnection

enum ZOperationID: Int, CaseIterable {

	case oNone               // default operation : does nothing

    // start up / onboard --> order of operations

    case oStartingUp
	case oUserPermissions
    case oMacAddress
    case oObserveUbiquity
    case oCheckAvailability  // vs no account
    case oUbiquity
    case oFetchUserID
    case oFetchUserRecord

    // finish up          --> order of operations

	case oManifest           // all these are LOCAL
	case oRoots
	case oHere
	case oLoadingIdeas
	case oFavorites			 // MINE ONLY
	case oWrite
	case oDone

    // miscellaneous      --> no particular order

	case oMigrateFromCloud
	case oSavingLocalData    // LOCAL
	case oResolveMissing
    case oFinishing
    case oBookmarks			 // MINE ONLY
	case oResolve
	case oAdopt
	case oEnd

	var useTimer: Bool {
		switch self {
			case .oLoadingIdeas, .oWrite,
				 .oRoots: return true
			default:      return false
		}
	}

	var	    doneOps : ZOpIDsArray { return [.oNone, .oDone, .oFinishing] }
	var    countOps : ZOpIDsArray { return [.oLoadingIdeas] }
	var mineOnlyOps : ZOpIDsArray { return [.oDone, .oBookmarks, .oFavorites] }
	var   bothDBOps : ZOpIDsArray { return [.oWrite, .oHere, .oRoots, .oManifest, .oLoadingIdeas, .oSavingLocalData, .oResolveMissing] }
	var    localOps : ZOpIDsArray { return [.oWrite, .oDone, .oUbiquity, .oFavorites, .oFinishing, .oMacAddress, .oStartingUp, .oFetchUserID, .oUserPermissions, .oObserveUbiquity, .oFetchUserRecord, .oCheckAvailability] + bothDBOps }

	var forMineOnly : Bool   { return mineOnlyOps.contains(self) }
	var alwaysBoth  : Bool   { return   bothDBOps.contains(self) }
	var isLocal     : Bool   { return    localOps.contains(self) }
	var isDoneOp    : Bool   { return     doneOps.contains(self) }
	var showCount   : Bool   { return    countOps.contains(self) }
	var description : String { return "\(self)".substring(fromInclusive: 1).unCamelcased }                // space separated words
	var countStatus : String { return !showCount ? kEmpty : " \(gRemoteStorage.countStatus)" }
	var fullStatus  : String { return description + countStatus }

}

class ZOperations: NSObject {

	let             queue = OperationQueue()
	var         currentOp = ZOperationID.oStartingUp
	var   onCloudResponse :      AnyClosure?
    var       lastOpStart :            Date?
	var        opDuration :    TimeInterval  { return -(lastOpStart?.timeIntervalSinceNow ?? .zero) }
	var      shouldCancel :            Bool  { return !currentOp.isDoneOp && !currentOp.useTimer && (opDuration > 5.0) }
	var     debugTimeText :          String  { return "\(Double(gDeciSecondsSinceLaunch) / 10.0)" }
	var     operationText :          String  { return currentOp.description }
	func unHang()                            { if gStartupLevel != .firstStartup { onCloudResponse?(0) } }
	func printOp(_ message: String = kEmpty) { printDebug(.dOps, operationText + message) }
	func invokeOperation(for identifier: ZOperationID, cloudCallback: AnyClosure?) throws                                  {}
	func invokeMultiple (for identifier: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping BooleanClosure) {}

    var isConnectedToInternet: Bool {
        var flags = SCNetworkReachabilityFlags(rawValue: 0)

        if  let host = SCNetworkReachabilityCreateWithName(nil, "www.apple.com"),
            !SCNetworkReachabilityGetFlags(host, &flags) {
            return false
        }

        let     isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)

        return isReachable && !needsConnection
    }

    @discardableResult func cloudStatusChanged() -> Bool {
		let           hasInternet = ZReachability.isConnectedToNetwork()
        let      changedConnected =               hasInternet != gHasInternet
        let      changedStatus    = gRecentCloudAccountStatus != gCloudAccountStatus
        gHasInternet              = hasInternet
        gRecentCloudAccountStatus = gCloudAccountStatus

        return changedConnected || changedStatus
    }

	func cloudFire() {
		if  shouldCancel {
			gBatches.unHang()
		}

		if  cloudStatusChanged() {
			gSignal([.spDataDetails]) // show change in cloud status

			// //////////////////////////////////////////////
			// assure that we can perform cloud operations //
			// //////////////////////////////////////////////

			if  gHasInternet && gIsReadyToShowUI {
				let identifier: ZBatchID = gCloudStatusIsActive ? .bResumeCloud : .bNewAppleID

				gBatches.batch(identifier) { iResult in
					if  gCloudStatusIsActive {
						gFavorites.updateAllFavorites()
					}

					gRelayoutMaps()
				}
			}
		}
	}

	func updateStatus() {
		var signals: ZSignalKindArray = [.spDataDetails]     // show change in cloud status

		if !gHasFinishedStartup {
			signals.append(.spStartupStatus)         // show current op in splash view
			printOp()
		}

		gSignal(signals)
	}

    func setupAndRun(_ operationIDs: ZOpIDsArray, onCompletion: @escaping Closure) {
        if  queue.operationCount > 30 {
            gAlerts.showAlert("overloading queue", "programmer error", "send an email to sand@gizmolab.com") { iObject in
                onCompletion()
            }

			return
        }

        queue.isSuspended = true
        let         saved = gDatabaseID

        for operationID in operationIDs + [.oFinishing] {
			let blockOperation = BlockOperation { [self] in
				FOREGROUND { [self] in

					// /////////////////////////////////////////////////////////////
					// ignore operations that are not local when have no internet //
					// /////////////////////////////////////////////////////////////

					if  !operationID.isLocal && !gCloudStatusIsActive {
						onCompletion()
					} else {
						currentOp         = operationID            // if hung, it happened inside this op

						// ////////////////////////////////////////////////////
						// susend queue until operation calls its closure... //
						// ////////////////////////////////////////////////////

						queue.isSuspended = true
						lastOpStart       = Date()

						invokeMultiple(for: operationID, restoreToID: saved) { [self] iResult in

							// /////////////////////
							// ...unsuspend queue //
							// /////////////////////

							queue.isSuspended = false

							if  currentOp == .oFinishing {

								// //////////// //
								// end of batch //
								// //////////// //

								onCompletion()
							}
						}
					}
				}
			}

            add(blockOperation)
        }

        queue.isSuspended = false
    }

    func add(_ operation: Operation) {
		if  let prior: Operation = queue.operations.last {
            operation.addDependency(prior)
        } else {
            queue.qualityOfService            = .background
            queue.maxConcurrentOperationCount = 1
        }

        queue.addOperation(operation)
    }

}
