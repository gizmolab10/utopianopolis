//
//  ZRemoteStoresManager.swift
//  Zones
//
//  Created by Jonathan Sand on 5/8/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
import CloudKit


let gRemoteStoresManager = ZRemoteStoresManager()
var     gManifest: ZManifest     { return gRemoteStoresManager.manifest }
var gCloudManager: ZCloudManager { return gRemoteStoresManager.currentCloudManager }
var        gTrash: Zone?   { get { return gRemoteStoresManager.trashZone } set { gRemoteStoresManager.trashZone = newValue } }
var         gRoot: Zone?   { get { return gRemoteStoresManager.rootZone }  set { gRemoteStoresManager.rootZone  = newValue } }
var         gHere: Zone    { get { return gManifest.hereZone }             set { gManifest.hereZone             = newValue } }


class ZRemoteStoresManager: NSObject {


    let             container = CKContainer(identifier: cloudID)
    var      storageModeStack = ZModes ()
    var       recordsManagers = [ZStorageMode : ZCloudManager]()
    var manifestByStorageMode = [ZStorageMode : ZManifest] ()
    var          userRecordID: CKRecordID?
    var currentRecordsManager: ZRecordsManager { return recordsManagerFor(gStorageMode) }
    var   currentCloudManager: ZCloudManager   { return cloudManagerFor(gStorageMode) }
    var      rootProgenyCount: Int             { return (rootZone?.progenyCount ?? 0) + (rootZone?.count ?? 0) + 1 }
    var              manifest: ZManifest       { return manifest(for: gStorageMode) }
    var             trashZone: Zone?     { get { return currentRecordsManager.trashZone } set { currentRecordsManager.trashZone = newValue } }
    var              rootZone: Zone?     { get { return currentRecordsManager.rootZone }  set { currentRecordsManager.rootZone  = newValue } }


    func rootZone(for mode: ZStorageMode) -> Zone? { return recordsManagerFor(mode).rootZone }


    func cancel() {
        currentCloudManager.currentOperation?.cancel()
    }

    func manifest(for mode: ZStorageMode) -> ZManifest {
        var manifest = manifestByStorageMode[mode]

        if  manifest == nil {
            let            manifestName = manifestNameForMode(mode)
            let    recordID: CKRecordID = CKRecordID(recordName: manifestName)
            let    record:   CKRecord   = CKRecord(recordType: manifestTypeKey, recordID: recordID)
            manifest                    = ZManifest(record: record, storageMode: .mineMode) // every manifest gets stored in .mine
            manifest!     .manifestMode = mode
            manifestByStorageMode[mode] = manifest
        }

        return manifest!
    }


    func cloudManagerFor(_ storageMode: ZStorageMode) -> ZCloudManager {
        return recordsManagerFor(storageMode) as! ZCloudManager
    }


    func recordsManagerFor(_ storageMode: ZStorageMode) -> ZRecordsManager {
        if storageMode == .favoritesMode {
            return gFavoritesManager
        }

        for storageMode in [ZStorageMode.everyoneMode, ZStorageMode.mineMode] {
            if  recordsManagers[storageMode] == nil {
                recordsManagers[storageMode] = ZCloudManager(storageMode)
            }
        }

        return recordsManagers[storageMode]!
    }


    func databaseForMode(_ mode: ZStorageMode) -> CKDatabase? {
        switch mode {
        case .everyoneMode: return container.publicCloudDatabase
        case   .sharedMode: return container.sharedCloudDatabase
        case     .mineMode: return container.privateCloudDatabase
        default:            return nil
        }
    }


    func authenticate(_ onCompletion: AnyClosure?) {
        fetchUser() { iRecordIDs in
            if iRecordIDs.count > 0 {
                self.userRecordID = iRecordIDs[0]
            }

            self.container.accountStatus { (iStatus, iError) in
                switch iStatus {
                case .available: onCompletion?(0)
                default:         onCompletion?(iError)
                }
            }
        }

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


    }


    func fetchUser(_ onCompletion: @escaping RecordIDsClosure) {
        container.fetchUserRecordID() { recordID, error in
            if  error == nil && recordID != nil {
                onCompletion([recordID!])
            } else {
                self.columnarReport(" ERROR", error?.localizedDescription ?? "failed to fetch user record id; reason unknown")
                onCompletion([])
            }
        }
    }
    

    func establishRoot(_ storageMode: ZStorageMode, _ onCompletion: IntClosure?) {
        switch storageMode {
        case .favoritesMode: onCompletion?(0)
        default:             cloudManagerFor(storageMode).establishRoot(onCompletion)
        }
    }


    func establishHere(_ storageMode: ZStorageMode, _ onCompletion: IntClosure?) {
        let manifest = self.manifest(for: storageMode)
        let     here = manifest.hereZone

        if storageMode == .favoritesMode, let root = gFavoritesManager.rootZone {
            manifest.hereZone = root
        } else if here.record != nil && here.zoneName != nil {
            here.maybeNeedChildren()
        } else {
            cloudManagerFor(storageMode).establishHere(onCompletion)

            return
        }

        onCompletion?(0)
    }


    func pushMode(_ mode: ZStorageMode) {
        storageModeStack.append(gStorageMode)

        gStorageMode = mode
    }


    func popMode() {
        if storageModeStack.count > 0, let mode = storageModeStack.popLast() {
            gStorageMode = mode
        }
    }


    func resetBadgeCounter() {
        container.accountStatus { (iStatus, iError) in
            if iStatus == .available {
                let badgeResetOperation = CKModifyBadgeOperation(badgeValue: 0)

                badgeResetOperation.modifyBadgeCompletionBlock = { (error) -> Void in
                    if error == nil {
                        self.FOREGROUND {
                            zapplication.clearBadge()
                        }
                    }
                }

                self.container.add(badgeResetOperation)
            }
        }
    }
    

    func applyToAllZones(in modes: ZModes, _ closure: ZoneClosure) {
        for mode: ZStorageMode in modes {
            let zones = cloudManagerFor(mode).zonesByID

            for zone in zones.values {
                closure(zone)
            }
        }
    }
 

    func bookmarksFor(_ zone: Zone?) -> [Zone] {
        var zoneBookmarks = [Zone] ()

        if zone != nil, let recordID = zone?.record?.recordID {
            applyToAllZones(in: [.mineMode, .everyoneMode]) { iZone in
                if let link = iZone.crossLink, let record = link.record, recordID == record.recordID {
                    zoneBookmarks.append(iZone)
                }
            }
        }

        return zoneBookmarks
    }
    

    // MARK:- receive from cloud
    // MARK:-


    func receivedUpdateFor(_ recordID: CKRecordID) {
        resetBadgeCounter()
        gCloudManager.assureRecordExists(withRecordID: recordID, recordType: zoneTypeKey) { iRecord in
            if iRecord != nil {                                                 // TODO: extract storage mode from record id, i.e., the database
                let    zone = self.currentCloudManager.zoneForRecord(iRecord!)  // TODO: currentCloudManager is wrong here
                zone.record = iRecord
                let  parent = zone.parentZone

                if  zone.showChildren {
                    self.FOREGROUND {
                        self.signalFor(parent, regarding: .redraw)

                        gOperationsManager.children(.restore) {
                            self.signalFor(parent, regarding: .redraw)
                        }
                    }
                }
            }
        }
    }

}
