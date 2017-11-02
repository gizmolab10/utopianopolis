//
//  ZUserManager.swift
//  iFocus
//
//  Created by Jonathan Sand on 10/26/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
import CloudKit


let gUserManager = ZUserManager()


class ZUserManager : NSObject {


    var            user : ZUser?
    var    userIdentity : CKUserIdentity?
    var   isSpecialUser : Bool { return user?.access == .eAccessFull }
    let makeUserSpecial = false


    func userHasAccess(_ zone: Zone) -> Bool {
        return isSpecialUser || zone.ownerID == nil || zone.ownerID!.recordName == gUserRecordID
    }


    func authenticate(_ onCompletion: AnyClosure?) {
        gContainer.accountStatus { (iStatus, iError) in
            self.fetchUser() {
                if  let recordName = gUserRecordID {
                    let ckRecordID = CKRecordID(recordName: recordName)

                    gCloudManager.assureRecordExists(withRecordID: ckRecordID, recordType: CKRecordTypeUserRecord) { (iUserRecord: CKRecord?) in
                        if  let  record = iUserRecord {
                            let    user = ZUser(record: record, storageMode: gStorageMode)
                            self  .user = user

                            if  self.makeUserSpecial {
                                user.access = .eAccessFull

                                user.needFlush()
                            }
                        }

                        self.fetchUserIdentity(for: ckRecordID) {
                            onCompletion?(0)
                        }
                    }
                } else {
                    // fubar, no cloud kit account
                    onCompletion?(0)
                }
            }
        }
    }


    func fetchUserIdentity(for iRecordID: CKRecordID, _ onCompletion: @escaping Closure) {
        gContainer.discoverUserIdentity(withUserRecordID: iRecordID) { (iCKUserIdentity, iError) in
            if  iError != nil {
                gAlertManager.report(error: iError, "failed to fetch user id; reason unknown")
            } else if iCKUserIdentity != nil {
                self.userIdentity = iCKUserIdentity
//            } else {
//                gAlertManager.report(error: CKError(_nsError: NSError(domain: "yikes", code: 9, userInfo: nil)))
            }

            onCompletion()
        }
    }


    func fetchUser(_ onCompletion: @escaping Closure) {
        gContainer.fetchUserRecordID() { iRecordID, iError in
            if  iError != nil {
                gAlertManager.report(error: iError, "failed to fetch user record id; reason unknown")
            } else {
                gUserRecordID = iRecordID?.recordName
            }

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
