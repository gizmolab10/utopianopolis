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

    // start up / onboard --> order of operations at launch

	case oStartingUp
	case oConfigureStorage   // data file locations
	case oUserPermissions
	case oMacAddress
	case oObserveUbiquity
	case oGetCloudStatus     // is icloud account available? (exists and accessible)
	case oUbiquity
	case oFetchUserID        // needs cloud access
	case oLoadManifest
	case oLoadingIdeas       // from core data or from cloud kit
	case oManifest           // all these are LOCAL (from files or core data)
	case oRoots
	case oFavorites			 // MINE ONLY
	case oHere
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
			case .oLoadingIdeas,
				 .oWrite,
				 .oRoots: return true
			default:      return false
		}
	}

	var	    doneOps : ZOpIDsArray { return [.oNone, .oDone, .oFinishing] }
	var    countOps : ZOpIDsArray { return [.oLoadingIdeas] }
	var mineOnlyOps : ZOpIDsArray { return [.oDone, .oBookmarks, .oFavorites, .oConfigureStorage] }
	var   bothDBOps : ZOpIDsArray { return [.oWrite, .oAdopt, .oHere, .oRoots, .oManifest, .oLoadManifest, .oLoadingIdeas, .oSavingLocalData, .oResolveMissing, .oMigrateFromCloud] }
	var    localOps : ZOpIDsArray { return [.oWrite, .oAdopt, .oDone, .oUbiquity, .oFavorites, .oFinishing, .oMacAddress, .oStartingUp, .oConfigureStorage, .oFetchUserID, .oUserPermissions, .oObserveUbiquity, .oGetCloudStatus] + bothDBOps }

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
	var     operationText :          String  { return currentOp.description }
	func unHang()                            { if gStartupLevel != .firstStartup { onCloudResponse?(0) } }
	func printOp(_ message: String = kEmpty) { printDebug(.dOps, operationText + message) }
	func invokeOperation(for identifier: ZOperationID, onCompletion: AnyClosure?) throws                                  {}
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

			// /////////////////////////////////////////// //
			// assure that we can perform cloud operations //
			// /////////////////////////////////////////// //

			if  gHasInternet && gIsReadyToShowUI {
				let identifier: ZBatchID = gCloudStatusIsActive ? .bResumeCloud : .bNewAppleID

				gBatches.batch(identifier) { iResult in
					if  gCloudStatusIsActive {
						gFavoritesCloud.updateAllFavorites()
					}

					gRelayoutMaps()
				}
			}
		}
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
					if  !operationID.isLocal && gCloudStatusIsDead {

						// ////////////////////////////////////////////////////////// //
						// ignore operations that are not local when have no internet //
						// ////////////////////////////////////////////////////////// //

						onCompletion()
					} else {
						currentOp         = operationID            // if hung, it happened inside this op
						lastOpStart       = Date()
						queue.isSuspended = true

						// ///////////////////////////////////////////////// //
						// susend queue until operation calls its closure... //
						// ///////////////////////////////////////////////// //

						invokeMultiple(for: operationID, restoreToID: saved) { [self] iResult in

							// ////////////////// //
							// ...unsuspend queue //
							// ////////////////// //

							queue.isSuspended = false

							if  currentOp.isDoneOp {

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
