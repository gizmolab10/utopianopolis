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

	case oNone               // default operation does nothing

    // start up / onboard

    case oStartUp            // NB: order here is order of operations (except miscellaneous)
	case oUserPermissions
    case oMacAddress
    case oObserveUbiquity
    case oCheckAvailability  // vs no account
    case oUbiquity
    case oFetchUserID
    case oFetchUserRecord

    // continue

	case oRoots
	case oRestoreIdeas       // LOCAL
	case oManifest
	case oLoadingFromFile    // LOCAL
    case oHere
	case oResolveMissing
	case oDone

    // miscellaneous

	case oMigrateFromCloud
	case oSaveCoreData       // LOCAL
    case oCompletion
	case oFavorites			 // MINE ONLY
    case oBookmarks			 // MINE ONLY
	case oRecents  			 // MINE ONLY
	case oResolve
	case oRecount
	case oAdopt

	var progressTime : Int {
		switch self {
			case .oRestoreIdeas:      return gCanLoad      ? 160 : 0
			case .oMigrateFromCloud:  return gNeedsMigrate ?  50 : 0
			case .oLoadingFromFile:   return gReadFiles    ?  30 : 0
			case .oFetchUserRecord:   return  9
			case .oMacAddress:        return  5
			case .oUserPermissions:   return  5
			case .oCheckAvailability: return  4
			case .oObserveUbiquity:   return  4
			case .oUbiquity:          return  4
			case .oFetchUserID:       return  4
			case .oResolve:           return  4
			case .oRecount:           return  3
			case .oManifest:          return  3
			case .oAdopt:             return  2
			default:                  return  1
		}
	}

	var useTimer: Bool {
		switch self {
			case .oLoadingFromFile:       return gReadFiles
			case .oRestoreIdeas, .oRoots: return true
			default:                      return false
		}
	}

	var	    doneOps : ZOpIDsArray { return [.oNone, .oDone, .oCompletion] }
	var    countOps : ZOpIDsArray { return [.oLoadingFromFile, .oRestoreIdeas] }
	var mineOnlyOps : ZOpIDsArray { return [.oDone, .oRecents, .oBookmarks, .oFavorites] }
	var   bothDBOps : ZOpIDsArray { return [.oHere, .oRoots, .oLoadingFromFile, .oManifest, .oRestoreIdeas, .oSaveCoreData, .oResolveMissing] }
	var    localOps : ZOpIDsArray { return [.oHere, .oRoots, .oLoadingFromFile, .oUbiquity, .oFavorites, .oCompletion, .oMacAddress, .oStartUp,
											.oFetchUserID, .oRestoreIdeas, .oSaveCoreData, .oUserPermissions, .oObserveUbiquity,
											.oFetchUserRecord, .oCheckAvailability] }

	var forMineOnly : Bool   { return mineOnlyOps.contains(self) }
	var alwaysBoth  : Bool   { return   bothDBOps.contains(self) }
	var isLocal     : Bool   { return    localOps.contains(self) }
	var isDoneOp    : Bool   { return     doneOps.contains(self) }
	var showCount   : Bool   { return    countOps.contains(self) }
	var description : String { return "\(self)".substring(fromInclusive: 1).unCamelcased }                // space separated words
	var countStatus : String { return !showCount ? "" : " \(countText)" }
	var fullStatus  : String { return description + countStatus }

	var countText : String {
		let (z, p) = gRemoteStorage.totalRecordsCounts     // count of z records
		let suffix = p == 0 ? "" :  " of \(p)"
		return "\(z)" + suffix
	}

}

func gSetProgressTime(for op: ZOperationID) {
	if !gHasFinishedStartup, op != .oUserPermissions {
		gAssureProgressTimesAreLoaded()

		let priorTime = gGetAccumulatedProgressTime(untilExcluding: op)
		let delta     = gStartup.count - priorTime

		if  delta    >= 1.5 {
			gProgressTimes[op] = delta
		}

		gStoreProgressTimes()
	}
}

func gGetAccumulatedProgressTime(untilExcluding op: ZOperationID) -> Double {
	gAssureProgressTimesAreLoaded()

	let opValue = op.rawValue
	var     sum = 0.0

	for opID in ZOperationID.allCases {
		if  opValue > opID.rawValue {          // all ops prior to op parameter
			sum += gProgressTimes[opID] ?? 1.0
		}
	}

	return sum
}

var gTotalTime : Double {
	gAssureProgressTimesAreLoaded()

	return gProgressTimes.values.reduce(0, +)
}

class ZOperations: NSObject {

	let             queue = OperationQueue()
	var   onCloudResponse :     AnyClosure?
    var       lastOpStart :           Date?
	var         currentOp :   ZOperationID  = .oStartUp
	var        opDuration :   TimeInterval  { return -(lastOpStart?.timeIntervalSinceNow ?? 0.0) }
	var      shouldCancel :           Bool  { return !currentOp.isDoneOp && !currentOp.useTimer && (opDuration > 5.0) }
	var     debugTimeText :         String  { return "\(Double(gDeciSecondsSinceLaunch) / 10.0)" }
	func printOp(_ message: String = "")    { printDebug(.dOps, operationText + message) }
	func unHang()                           { if gStartupLevel != .firstTime { onCloudResponse?(0) } }
	func invokeOperation(for identifier: ZOperationID, cloudCallback: AnyClosure?) throws                                  {} 
	func invokeMultiple (for identifier: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping BooleanClosure) {}

    var operationText: String {
//		let d = gBatches.currentDatabaseID?.identifier ?? " " // requires an extra trailing space seperator
		let o = currentOp.description

        return o
	}
    
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

					gRedrawMaps()
				}
			}
		}
	}

	func updateStatus() {
		var signals: [ZSignalKind] = [.sStatus]     // show change in cloud status

		if !gHasFinishedStartup {
			signals.append(.sStartupStatus)         // show current op in splash view
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

        for operationID in operationIDs + [.oCompletion] {
            let blockOperation = BlockOperation {

                // /////////////////////////////////////////////////////////////
                // ignore operations that are not local when have no internet //
                // /////////////////////////////////////////////////////////////

				if  !operationID.isLocal && !gCloudStatusIsActive {
					onCompletion()
				} else {

					// ////////////////////////////////////////////////////
					// susend queue until operation calls its closure... //
					// ////////////////////////////////////////////////////

					FOREGROUND {
						gStartup.count        += 1.0					// every op should advance progress bar
						self.queue.isSuspended = true
						self.lastOpStart       = Date()
						self.currentOp         = operationID            // if hung, it happened inside this op

						self.updateStatus()

						self.invokeMultiple(for: operationID, restoreToID: saved) { iResult in
							FOREGROUND {
								if  self.currentOp == .oCompletion {

									// /////////////////////////////////////
									// done with this batch of operations //
									// /////////////////////////////////////

									onCompletion()
								} else {
									gSetProgressTime(for: operationID)
								}

								// /////////////////////
								// ...unsuspend queue //
								// /////////////////////

								self.queue.isSuspended = false
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
