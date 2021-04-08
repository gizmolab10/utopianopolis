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

var gCloudStatusIsActive      : Bool { return gCloudAccountStatus == .active }
var gCloudAccountStatus       = ZCloudAccountStatus.begin
var recentCloudAccountStatus  = gCloudAccountStatus
var gHasInternet              = true

class ZOnboarding : ZOperations {

    var          user : ZUser?
	var    macAddress : String?
	var hasFullAccess : Bool { return !gDebugAccess && (user?.access ?? .eNormal) == .eFull }

    // MARK:- internals
    // MARK:-

	@objc func completeOnboarding(_ notification: Notification) {
		gBatches.batch(.bNewAppleID) { iResult in
			gFavorites.updateAllFavorites()
			gRedrawMaps()
		}
	}

    // MARK:- operations
    // MARK:-

	override func invokeMultiple(for operationID: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping BooleanClosure) {
        onCloudResponse = { flag in onCompletion(false) }

		switch operationID {
			case .oMacAddress:        getMAC();                 onCompletion(true)    // true means op is handled
			case .oObserveUbiquity:   observeUbiquity();        onCompletion(true)
			case .oUserPermissions:   getPermissionFromUser() { onCompletion(true) }
			case .oCheckAvailability: checkAvailability       { onCompletion(true) }
			case .oUbiquity:          ubiquity                { onCompletion(true) }
			case .oFetchUserID:       fetchUserID             { onCompletion(true) }
			case .oFetchUserRecord:   fetchUserRecord         { onCompletion(true) }
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

	func checkAvailability(_ onCompletion: @escaping Closure) {
		if !gHasInternet {
			onCompletion()
		} else {
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
	}

	func ubiquity(_ onCompletion: @escaping Closure) {
        if  FileManager.default.ubiquityIdentityToken == nil {

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
		if  let              record = gUserRecord {
			gCoreDataStack.deferUntilAvailable(for: .oFetch) {
				self.user           = ZUser.create(record: record, databaseID: gDatabaseID)
				gCloudAccountStatus = .active

				onCompletion()
			}
		} else if gCloudAccountStatus == .available,
            let      recordName = gUserRecordID {
            let      ckRecordID = CKRecordID(recordName: recordName)

            gEveryoneCloud?.assureRecordExists(withRecordID: ckRecordID, recordType: kUserType) { (iUserRecord: CKRecord?) in
                if  let          record = iUserRecord {
                    let            user = ZUser.create(record: record, databaseID: gDatabaseID)
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
