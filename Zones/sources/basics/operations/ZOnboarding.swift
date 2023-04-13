//
//  ZOnboarding.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/26/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

enum ZCloudAccountStatus: Int {
	case none
	case begin
	case available
	case active
}

var gCloudStatusIsActive      : Bool { return gCloudAccountStatus == .active }
var gCloudStatusIsAvailable   : Bool { return gCloudAccountStatus == .available }
var gCloudAccountStatus       = ZCloudAccountStatus.begin
var gRecentCloudAccountStatus = gCloudAccountStatus
var gHasInternet              = true

class ZOnboarding : ZOperations {

    var          user : ZUser?
	var    macAddress : String?
	var hasFullAccess : Bool { return (user?.access ?? .eNormal) == .eFull }

    // MARK: - internals
    // MARK: -

	@objc func completeOnboarding(_ notification: Notification) {
		gBatches.batch(.bNewAppleID) { iResult in
			gFavorites.updateAllFavorites()
			gRelayoutMaps()
		}
	}

    // MARK: - operations
    // MARK: -

	override func invokeMultiple(for operationID: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping BooleanClosure) {
        onCloudResponse = { flag in onCompletion(false) }

		switch operationID {
			case .oMacAddress:        getMAC();                 onCompletion(true)    // true means op is handled
			case .oObserveUbiquity:   observeUbiquity();        onCompletion(true)
			case .oUserPermissions:   getPermissionFromUser() { onCompletion(true) }
			case .oGetCloudStatus:    getCloudStatus          { onCompletion(true) }
			case .oUbiquity:          ubiquity                { onCompletion(true) }
			case .oFetchUserID:       fetchUserID             { onCompletion(true) }
			default:                                            onCompletion(false)
		}
    }

	func getPermissionFromUser(onCompletion: @escaping Closure) {
		if  let c = gStartupController {
			c.getPermissionFromUser(onCompletion: onCompletion)
		} else {
			onCompletion()
		}
	}

	func observeUbiquity() {
		gNotificationCenter.addObserver(self, selector: #selector(ZOnboarding.completeOnboarding), name: .NSUbiquityIdentityDidChange, object: nil)
	}

	func getCloudStatus(_ onCompletion: @escaping Closure) {
		if !gHasInternet {
			onCompletion()
		} else {
			gCloudContainer.accountStatus { (iStatus, iError) in
				if  iStatus            == .available {
					gCloudAccountStatus = .available

					// //////////////////// //
					// ONBOARDING CONTINUES //
					// //////////////////// //
				}

				onCompletion()
			}
		}
	}

	func ubiquity(_ onCompletion: @escaping Closure) {
        if  gFileManager.ubiquityIdentityToken == nil {

            // //////////////////// //
            // ONBOARDING CONTINUES //
            // //////////////////// //

            cloudStatusChanged()
        }

        onCompletion()
    }

	func fetchUserID(_ onCompletion: @escaping Closure) {
        if  gCloudAccountStatus != .available || !gUseCloud {
            onCompletion()
        } else {
            gCloudContainer.fetchUserRecordID() { iRecordID, iError in
				FOREGROUND {
					gAlerts.alertError(iError, "failed to fetch user record id from cloud") { iHasError in
						if !iHasError {

							// ////////////////////////////////////////// //
							// persist for file read on subsequent launch //
							//   also: for determining write permission   //
							// ////////////////////////////////////////// //

							if  let      recordName = iRecordID?.recordName {
								self.user           = ZUser.uniqueUser(recordName: recordName, in: gDatabaseID)
								gUserRecordName     = recordName
								gCloudAccountStatus = .active

								// ////////////////////// //
								// ONBOARDING IS COMPLETE //
								// ////////////////////// //
							}
						}

						onCompletion()
					}
				}
            }
        }
    }

}
