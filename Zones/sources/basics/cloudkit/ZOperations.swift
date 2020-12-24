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
	case oInternet
	case oUserPermissions
    case oMacAddress
    case oObserveUbiquity
    case oCheckAvailability  // vs no account
    case oUbiquity
    case oFetchUserID
    case oFetchUserRecord

    // continue

    case oCloud
    case oManifest
    case oReadFile           // LOCAL
    case oFoundIdeas         // LOCAL
	case oFavorites			 // MINE ONLY
	case oRecents  			 // MINE ONLY
	case oRoots
    case oHere
	case oStartupDone

    // finish

    case oFinishUp
	case oSubscribe
	case oAllIdeas
	case oAdopt
	case oRecount
    case oDone

    // miscellaneous

	case oResolve
	case oFetchAndMerge
	case oNeededIdeas        // after children so favorite targets resolve properly
    case oSaveToCloud        // zones, traits, destroy
	case oParentIdeas        // after fetch so colors resolve properly
	case oChildIdeas
    case oEmptyTrash
    case oCompletion
    case oBookmarks			 // MINE ONLY
	case oAllTraits
    case oLostIdeas
	case oNewIdeas
    case oUndelete
    case oRefetch            // user defaults list of record ids
    case oTraits

	var progressTime : Double {
		switch self {
			case .oReadFile:        return 30.0
			case .oTraits:          return 16.0
//			case .oAllTraits:       return 11.0
			case .oAllIdeas:        return  8.0
			case .oSubscribe:       return  7.0
			case .oNewIdeas:        return  7.0
			case .oNeededIdeas:     return  6.0
			case .oManifest:        return  6.0
			case .oResolve:         return  4.0
			case .oFinishUp:        return  3.0
			case .oRecount:         return  2.0
			case .oAdopt:           return  2.0
			default:                return  1.0
		}
	}

	var useTimer: Bool {
		switch self {
			case .oSubscribe,
				 .oAllTraits,
				 .oAllIdeas,
				 .oNewIdeas,
				 .oTraits:   return true
			case .oReadFile: return gDebugModes.useFiles
			default:         return false
		}
	}

    var isLocal     : Bool { return localOperations.contains(self) }
	var isDeprecated: Bool { return   deprecatedOps.contains(self) }
	var needsActive : Bool { return   needActiveOps.contains(self) }
	var forMineOnly : Bool { return     mineOnlyOps.contains(self) }
	var alwaysBoth  : Bool { return       bothDBOps.contains(self) }
	var isDoneOp    : Bool { return         doneOps.contains(self) }

	var description : String { return "\(self)".substring(fromInclusive: 1).unCamelcased }
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

let	        doneOps : [ZOperationID] = [.oNone, .oDone, .oCompletion]
let   deprecatedOps : [ZOperationID] = [.oParentIdeas]
let   needActiveOps : [ZOperationID] = [.oSaveToCloud, .oTraits]
let     mineOnlyOps : [ZOperationID] = [.oBookmarks, .oFavorites, .oRecents, .oDone]
let       bothDBOps : [ZOperationID] = [.oHere, .oRoots, .oReadFile, .oManifest, .oSubscribe]
let localOperations : [ZOperationID] = [.oHere, .oRoots, .oFoundIdeas, .oReadFile, .oInternet, .oUbiquity,
										.oFavorites, .oCompletion, .oMacAddress, .oFetchUserID, .oUserPermissions,
										.oObserveUbiquity, .oFetchUserRecord, .oCheckAvailability]

class ZOperations: NSObject {

	let             queue = OperationQueue()
	var         currentOp :  ZOperationID  = .oNone
	var      shouldCancel :          Bool  { return !currentOp.isDoneOp && !currentOp.useTimer && -(inverseOpDuration ?? 0.0) > 5.0 }
	var     debugTimeText :        String  { return "\(Double(gDeciSecondsSinceLaunch) / 10.0)" }
	var inverseOpDuration :  TimeInterval? { return lastOpStart?.timeIntervalSinceNow }
	var         cloudFire :  TimerClosure?
	var   onCloudResponse :    AnyClosure?
    var       lastOpStart :          Date?
	func printOp(_ message: String)        { columnarReport(mode: .dOps, operationText, message) }
	func unHang()                          { if gStartupLevel != .firstTime { onCloudResponse?(0) } }
	func invokeOperation(for identifier: ZOperationID, cloudCallback: AnyClosure?) throws                                  {} 
	func invokeMultiple (for identifier: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping BooleanClosure) {}

    var operationText: String {
		let i = gBatches.currentDatabaseID?.identifier
		let d = i == nil ? "  " : i! + " "
        var s = String(describing: currentOp)
        s     = s.substring(fromInclusive: 1)
        let c = s.substring(  toExclusive: 1).lowercased()
        s     = s.substring(fromInclusive: 1)

        return d + c + s
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

                                gRedrawMaps()
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

					gStartup.count        += 1					// every op should advance progress bar
                    self.queue.isSuspended = true
					self.lastOpStart       = Date()
                    self.currentOp         = operationID        // if hung, it happened inside this op

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

							gSignal([.sStatus, .sStartupProgress]) // show change in cloud status and startup progress

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
