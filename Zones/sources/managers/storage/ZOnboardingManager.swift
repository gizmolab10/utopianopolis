//
//  ZOnboardingManager.swift
//  iFocus
//
//  Created by Jonathan Sand on 10/26/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
import CloudKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


var gIsSpecialUser: Bool { return gBatchManager.isSpecialUser }


class ZOnboardingManager : ZOperationsManager {


    var            user : ZUser?
    var   isSpecialUser : Bool { return user?.access == .eAccessFull }
    let makeUserSpecial = false


    // MARK:- API
    // MARK:-


    func onboard(_ onCompletion: Closure?) {
        setupAndRunOps(from: .observeUbiquity, to: .fetchUserRecord) {
            onCompletion?()
        }
    }


    // MARK:- internals
    // MARK:-


    func completeOnboarding(_ notification: Notification) {
        setupAndRun([.fetchUserRecord]) {}
    }


    // MARK:- operations
    // MARK:-


    override func performBlock(for operationID: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping BooleanClosure) {
        switch operationID {
        case .observeUbiquity:  observeUbiquity();  onCompletion(true)      // true means op is handled
        case .accountStatus:    accountStatus     { onCompletion(true) }
        case .fetchUserID:      fetchUserID       { onCompletion(true) }
        case .internet:         internet          { onCompletion(true) }
        case .ubiquity:         ubiquity          { onCompletion(true) }
        case .fetchUserRecord:  fetchUserRecord   { onCompletion(true) }
        default:                                    onCompletion(false)     // false means op is not handled, so super should proceed
        }
    }


    func internet(_ onCompletion: @escaping Closure) {
        updateCloudStatus { iChanged in
            onCompletion()
        }
    }


    func observeUbiquity() {
        NotificationCenter.default.addObserver(self, selector: #selector(ZOnboardingManager.completeOnboarding), name: .NSUbiquityIdentityDidChange, object: nil)
    }


    func accountStatus(_ onCompletion: @escaping Closure) {
        gContainer.accountStatus { (iStatus, iError) in
            switch iStatus {
            case .available:
                gCloudAccountStatus = .available
            default:
                break
            }

            onCompletion()
        }
    }


    func fetchUserID(_ onCompletion: @escaping Closure) {
        gContainer.fetchUserRecordID() { iRecordID, iError in
            gAlertManager.alertError(iError, "failed to fetch user record id; reason unknown") { iHasError in
                if !iHasError {
                    gUserRecordID = iRecordID?.recordName

                    onCompletion()
                }
            }
        }
    }


    func ubiquity(_ onCompletion: @escaping Closure) {
        if FileManager.default.ubiquityIdentityToken == nil {
            updateCloudStatus { iChangesOccured in
                onCompletion()
            }
        } else {
            onCompletion()
        }
    }


    func fetchUserRecord(_ onCompletion: @escaping Closure) {
        if  let recordName = gUserRecordID,
            gCloudAccountStatus.rawValue >= ZCloudAccountStatus.available.rawValue {
            let ckRecordID = CKRecordID(recordName: recordName)

            gCloudManager.assureRecordExists(withRecordID: ckRecordID, recordType: CKRecordTypeUserRecord) { (iUserRecord: CKRecord?) in
                if  let          record = iUserRecord {
                    let            user = ZUser(record: record, databaseID: gDatabaseID)
                    self          .user = user
                    gCloudAccountStatus = .active

                    //////////////////////////
                    // ONBOARDING CONTINUES //
                    //////////////////////////

                    if  self.makeUserSpecial {
                        user.access = .eAccessFull

                        user.maybeNeedSave()
                    }
                } else {
                    let            name = ckRecordID.recordName
                    gCloudAccountStatus = .none

                    ////////////////////////
                    //  ONBOARDING STOPS  //
                    ////////////////////////

                    // see: shouldPerform

                    print("alert: user record \(name) does not exist")
                }

                onCompletion()
            }
        } else {
            onCompletion()
        }
    }


//    func status() {
//        [[CKContainer defaultContainer] accountStatusWithCompletionHandler:^(CKAccountStatus accountStatus, NSError *error) {
//            if (accountStatus == CKAccountStatusNoAccount) {
//            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sign in to iCloud"
//            message:@"Sign in to your iCloud account to write records. On the Home screen, launch Settings, tap iCloud, and enter your Apple ID. Turn iCloud Drive on. If you don't have an iCloud account, tap Create a new Apple ID."
//            preferredStyle:UIAlertControllerStyleAlert];
//            [alert addAction:[UIAlertAction actionWithTitle:@"Okay"
//            style:UIAlertActionStyleCancel
//            handler:nil]];
//            [self presentViewController:alert animated:YES completion:nil];
//            }
//            else {
//            // Insert your just-in-time schema code here
//            }
//            }]
//
//    }

}
