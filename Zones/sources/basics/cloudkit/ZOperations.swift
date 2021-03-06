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
	case oRestoreIdeas       // LOCAL
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
	case oRoots
    case oHere
	case oAllIdeas
	case oAllTraits
	case oStartupDone

    // finish

    case oFinishUp
	case oSubscribe
	case oAdopt
	case oRecount
    case oDone

    // miscellaneous

	case oMigrateFromCloud
	case oFetchAndMerge
	case oSaveCoreData       // LOCAL
	case oNeededIdeas        // after children so favorite targets resolve properly
    case oSaveToCloud        // zones, traits, destroy
	case oParentIdeas        // after fetch so colors resolve properly
	case oOwnedTraits
	case oChildIdeas
    case oEmptyTrash
    case oCompletion
	case oFoundIdeas         // LOCAL
	case oFavorites			 // MINE ONLY
    case oBookmarks			 // MINE ONLY
    case oLostIdeas
	case oNewIdeas
    case oUndelete
	case oRecents  			 // MINE ONLY
    case oRefetch            // user defaults list of record ids
	case oResolve
	case oTraits

	var progressTime : Int {
		switch self {
			case .oRestoreIdeas:      return gCanLoad      ? 160 : 0
			case .oMigrateFromCloud:  return gNeedsMigrate ?  50 : 0
			case .oReadFile:          return gReadFiles    ?  30 : 0
			case .oOwnedTraits:       return 11
			case .oCloud:             return 10
			case .oFetchUserRecord:   return  9
			case .oAllTraits:         return  8
			case .oAllIdeas:          return  8
			case .oNewIdeas:          return  7
			case .oNeededIdeas:       return  6
			case .oMacAddress:        return  5
			case .oUserPermissions:   return  5
			case .oCheckAvailability: return  4
			case .oObserveUbiquity:   return  4
			case .oUbiquity:          return  4
			case .oFetchUserID:       return  4
			case .oResolve:           return  4
			case .oTraits:            return  4
			case .oRecount:           return  3
			case .oManifest:          return  3
			case .oFinishUp:          return  3
			case .oSubscribe:         return  3
			case .oAdopt:             return  2
			default:                  return  1
		}
	}

	var useTimer: Bool {
		switch self {
			case .oReadFile: return gReadFiles
			case .oRestoreIdeas,
				 .oSubscribe,
				 .oAllTraits,
				 .oAllIdeas,
				 .oNewIdeas,
				 .oTraits,
				 .oRoots:    return true
			default:         return false
		}
	}

	var      deprecatedOps : ZOperationIDsArray { return [.oParentIdeas] }
	var needActiveCloudOps : ZOperationIDsArray { return [.oSaveToCloud, .oTraits] }
	var	           doneOps : ZOperationIDsArray { return [.oNone, .oDone, .oCompletion] }
	var        mineOnlyOps : ZOperationIDsArray { return [.oDone, .oRecents, .oBookmarks, .oFavorites] }
	var          bothDBOps : ZOperationIDsArray { return [.oHere, .oRoots, .oReadFile, .oManifest, .oSubscribe, .oRestoreIdeas, .oSaveCoreData] }
	var           localOps : ZOperationIDsArray { return [.oHere, .oRoots, .oReadFile, .oUbiquity, .oFavorites, .oFoundIdeas,
														  .oCompletion, .oMacAddress, .oFetchUserID, .oRestoreIdeas, .oSaveCoreData,
														  .oUserPermissions, .oObserveUbiquity, .oFetchUserRecord, .oCheckAvailability] }

	var needsActiveCloud : Bool { return needActiveCloudOps.contains(self) }
	var isDeprecated     : Bool { return      deprecatedOps.contains(self) }
	var forMineOnly      : Bool { return        mineOnlyOps.contains(self) }
	var alwaysBoth       : Bool { return          bothDBOps.contains(self) }
	var isLocal          : Bool { return           localOps.contains(self) }
	var isDoneOp         : Bool { return            doneOps.contains(self) }

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

class ZOperations: NSObject {

	let             queue = OperationQueue()
	var   onCloudResponse :     AnyClosure?
    var       lastOpStart :           Date?
	var         currentOp :   ZOperationID  = .oStartUp
	var        opDuration :   TimeInterval  { return -(lastOpStart?.timeIntervalSinceNow ?? 0.0) }
	var      shouldCancel :           Bool  { return !currentOp.isDoneOp && !currentOp.useTimer && (opDuration > 5.0) }
	var     debugTimeText :         String  { return "\(Double(gDeciSecondsSinceLaunch) / 10.0)" }
	func printOp(_ message: String)         { columnarReport(mode: .dOps, operationText, message) }
	func unHang()                           { if gStartupLevel != .firstTime { onCloudResponse?(0) } }
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

    func setupAndRun(_ operationIDs: ZOperationIDsArray, onCompletion: @escaping Closure) {
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

					gStartup.count        += 1.0					// every op should advance progress bar
                    self.queue.isSuspended = true
					self.lastOpStart       = Date()
                    self.currentOp         = operationID            // if hung, it happened inside this op

					if !gHasFinishedStartup {
						gSignal([.sStartupProgress])                // show current op in splash view
					}

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

							gSignal([.sStatus])            // show change in cloud status

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
