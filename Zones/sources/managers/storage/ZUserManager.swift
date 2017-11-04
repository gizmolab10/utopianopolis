//
//  ZUserManager.swift
//  iFocus
//
//  Created by Jonathan Sand on 10/26/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
import CloudKit


enum ZOnboardingState: Int {
    case internet
    case appleID            // ubquity?
    case accountStatus      // vs no account
    case fetchUserRecordID  //
    case assureUserExists   // record
    case cloudDrive         // ubiquity?
}


let gUserManager = ZUserManager()


class ZUserManager : NSObject {


    var            user : ZUser?
    var    userIdentity : CKUserIdentity?
    var   isSpecialUser : Bool { return user?.access == .eAccessFull }
    let makeUserSpecial = false


    func userHasAccess(_ zone: Zone) -> Bool {
        return isSpecialUser || zone.ownerID == nil || zone.ownerID!.recordName == gUserRecordID
    }


    func onboard(_ onCompletion: AnyClosure?) {
        internet {
            self.ubiquity {
                self.accountStatus {
                    self.fetchUserRecordID {
                        self.assureUserExists {
                            self.fetchUserIdentity {
                                onCompletion?(0)
                            }
                        }
                    }
                }
            }
        }
    }


    func internet(_ onCompletion: @escaping Closure) {
        onCompletion()
    }


    func ubiquity(_ onCompletion: @escaping Closure) {
        onCompletion()
    }


    func accountStatus(_ onCompletion: @escaping Closure) {
        gContainer.accountStatus { (iStatus, iError) in
            self.FOREGROUND {
                switch iStatus {
                case .available:
                    onCompletion()
                default:
                    // alert system prefs
                    break
                }
            }
        }
    }


    func assureUserExists(_ onCompletion: @escaping Closure) {
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

                    onCompletion()
                } else {
                    // alert ... i forgot what caused this
                }
            }
        }
    }


    func fetchUserRecordID(_ onCompletion: @escaping Closure) {
        gContainer.fetchUserRecordID() { iRecordID, iError in
            gAlertManager.alertError(iError, "failed to fetch user record id; reason unknown") { iHasError in
                if !iHasError {
                    gUserRecordID = iRecordID?.recordName

                    onCompletion()
                }
            }
        }
    }


    func fetchUserIdentity(_ onCompletion: @escaping Closure) {
        if  let recordName = gUserRecordID {
            let ckRecordID = CKRecordID(recordName: recordName)
            let  debugAuth = true

            gContainer.discoverUserIdentity(withUserRecordID: ckRecordID) { (iCKUserIdentity, iError) in
                let message = "failed to fetch user id; reason unknown"

                if  iError != nil {
                    gAlertManager.alertError(iError, message)
                } else if iCKUserIdentity != nil {
                    self.userIdentity = iCKUserIdentity
                } else if debugAuth {
                    let error = CKError(_nsError: NSError(domain: "yikes", code: 9, userInfo: nil))

                    gAlertManager.alertError(error, message)
                }

                onCompletion()
            }
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
