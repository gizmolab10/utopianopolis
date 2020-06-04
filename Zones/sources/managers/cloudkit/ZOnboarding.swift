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

var gCanAccessMyCloudDatabase : Bool { return gCloudAccountStatus == .active }
var gCloudAccountStatus       = ZCloudAccountStatus.begin
var recentCloudAccountStatus  = gCloudAccountStatus
var gHasInternet              = true

class ZOnboarding : ZOperations {

    var           user : ZUser?
    var isMasterAuthor : Bool { return user?.access == .eMaster || macAddress == "f0:18:98:eb:68:b2" || macAddress == "f4:0f:24:1f:1a:6a"}
    var     macAddress : String?

    // MARK:- internals
    // MARK:-

    @objc func completeOnboarding(_ notification: Notification) {
        FOREGROUND(canBeDirect: true) {
            gBatches.batch(.bNewAppleID) { iResult in
                gFavorites.updateAllFavorites()
                gRedrawGraph()
            }
        }
    }

    // MARK:- operations
    // MARK:-

	override func invokeMultiple(for operationID: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping BooleanClosure) {
        onCloudResponse = { iAny in onCompletion(false) }

        switch operationID {
		case .oMacAddress:        getMAC();           onCompletion(true)
		case .oObserveUbiquity:   observeUbiquity();  onCompletion(true)
        case .oCheckAvailability: checkAvailability { onCompletion(true) }    // true means op is handled
		case .oInternet:          checkConnection();  onCompletion(true)
		case .oUbiquity:          ubiquity          { onCompletion(true) }
        case .oFetchUserID:       fetchUserID       { onCompletion(true) }
		case .oFetchUserRecord:   fetchUserRecord   { onCompletion(true) }
        default:                                      onCompletion(false)     // false means op is not handled, so super should proceed
        }
    }

	func observeUbiquity() { gNotificationCenter.addObserver(self, selector: #selector(ZOnboarding.completeOnboarding), name: .NSUbiquityIdentityDidChange, object: nil) }
    func checkConnection() { gHasInternet = isConnectedToInternet }

	func checkAvailability(_ onCompletion: @escaping Closure) {
        gContainer.accountStatus { (iStatus, iError) in
            if  iStatus            == .available {
                gCloudAccountStatus = .available

                // ///////////////////////
                // ONBOARDING CONTINUES //
                // ///////////////////////
            }

            onCompletion()
        }
    }

	func ubiquity(_ onCompletion: @escaping Closure) {
        if FileManager.default.ubiquityIdentityToken == nil {

            // ///////////////////////
            // ONBOARDING CONTINUES //
            // ///////////////////////

            cloudStatusChanged()
        }

        onCompletion()
    }

	func fetchUserID(_ onCompletion: @escaping Closure) {
        if  gCloudAccountStatus != .available {
            onCompletion()
        } else {
            gContainer.fetchUserRecordID() { iRecordID, iError in
				FOREGROUND {
					gAlerts.alertError(iError, "failed to fetch user record id") { iHasError in
						if !iHasError {

							// /////////////////////////////////////////////
							// persist for file read on subsequent launch //
							//   also: for determining write permission   //
							// /////////////////////////////////////////////

							gUserRecordID = iRecordID?.recordName

							// ///////////////////////
							// ONBOARDING CONTINUES //
							// ///////////////////////
						}

						onCompletion()
					}
				}
            }
        }
    }

	func fetchUserRecord(_ onCompletion: @escaping Closure) {
		if  let          record = gUserRecord {
			user                = ZUser(record: record, databaseID: gDatabaseID)
			gCloudAccountStatus = .active

			onCompletion()
		} else if gCloudAccountStatus == .available,
            let      recordName = gUserRecordID {
            let      ckRecordID = CKRecord.ID(recordName: recordName)

            gEveryoneCloud?.assureRecordExists(withRecordID: ckRecordID, recordType: kUserType) { (iUserRecord: CKRecord?) in
                if  let          record = iUserRecord {
                    let            user = ZUser(record: record, databaseID: gDatabaseID)
                    self          .user = user
					gUserRecord         = record
					gCloudAccountStatus = .active

                    // ///////////////////////
                    // ONBOARDING CONTINUES //
                    // ///////////////////////

                    if  user.authorID  == nil {
                        user.authorID   = UUID().uuidString

                        user.needSave()
                    }

                    gAuthorID           = user.authorID
                } else {
                    let            name = ckRecordID.recordName
                    gCloudAccountStatus = .none

                    // /////////////////////
                    //  ONBOARDING STOPS  //
                    // /////////////////////

                    // see: shouldPerform

                    printDebug(.dError, "alert: user record \(name) does not exist")
                }

                onCompletion()
            }
        } else {
            onCompletion()
        }
    }

}
