//
//  ZUserManager.swift
//  iFocus
//
//  Created by Jonathan Sand on 10/26/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZUserManager : NSObject {


    var          user: ZUser?
    var  userRecordID: CKRecordID?
    var  userIdentity: CKUserIdentity?
    var isSpecialUser: Bool { return user?.access == .eAccessFull }


    func userHasAccess(_ zone: Zone) -> Bool {
        return isSpecialUser || zone.ownerID == nil || zone.ownerID == userRecordID
    }


    func authenticate(_ onCompletion: AnyClosure?) {
        fetchUser() {
            self.fetchUserID() {
                if  let recordID = self.userRecordID {
                    gCloudManager.assureRecordExists(withRecordID: recordID, recordType: CKRecordTypeUserRecord) { (iUserRecord: CKRecord?) in
                        if  let record = iUserRecord {
                            let   user = ZUser(record: record, storageMode: gStorageMode)
                            self .user = user
                        }

                        gContainer.accountStatus { (iStatus, iError) in
                            switch iStatus {
                            case .available: onCompletion?(0)
                            default:         onCompletion?(iError)
                            }
                        }
                    }
                }
            }
        }
    }


    func fetchUserID(_ onCompletion: @escaping Closure) {
        gContainer.discoverUserIdentity(withUserRecordID: userRecordID!) { (iCKUserIdentity, iError) in
            if  iError == nil {
                self.userIdentity = iCKUserIdentity
            } else {
                self.columnarReport(" ERROR", iError?.localizedDescription ?? "failed to fetch user id; reason unknown")
            }

            onCompletion()
        }
    }


    func fetchUser(_ onCompletion: @escaping Closure) {
        gContainer.fetchUserRecordID() { iRecordID, iError in
            if  iError == nil {
                self.userRecordID = iRecordID
            } else {
                self.columnarReport(" ERROR", iError?.localizedDescription ?? "failed to fetch user record id; reason unknown")
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
