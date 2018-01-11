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
var        gCloudManager : ZCloudManager { return gRemoteStoresManager.currentCloudManager }
var        gLostAndFound : Zone?         { return gRemoteStoresManager.lostAndFoundZone }
var            gManifest : ZManifest     { return gRemoteStoresManager.manifest }
var               gTrash : Zone?         { return gRemoteStoresManager.trashZone }
var                gRoot : Zone?   { get { return gRemoteStoresManager.rootZone } set { gRemoteStoresManager.rootZone  = newValue } }
var                gHere : Zone    { get { return gManifest.hereZone }            set { gManifest.hereZone             = newValue } }


class ZRemoteStoresManager: NSObject {


    var      storageModeStack = ZModes ()
    var       recordsManagers = [ZStorageMode : ZCloudManager]()
    var manifestByStorageMode = [ZStorageMode : ZManifest] ()
    var currentRecordsManager: ZRecordsManager { return recordsManagerFor(gStorageMode)! }
    var   currentCloudManager: ZCloudManager   { return cloudManagerFor(gStorageMode) }
    var      rootProgenyCount: Int             { return (rootZone?.progenyCount ?? 0) + (rootZone?.count ?? 0) + 1 }
    var      lostAndFoundZone: Zone?           { return currentRecordsManager.lostAndFoundZone }
    var             trashZone: Zone?           { return currentRecordsManager.trashZone }
    var              rootZone: Zone?     { get { return currentRecordsManager.rootZone }  set { currentRecordsManager.rootZone  = newValue } }
    var              manifest: ZManifest       { return manifest(for: gStorageMode) }


    func rootZone(for mode: ZStorageMode) -> Zone? { return recordsManagerFor(mode)?.rootZone }


    func clear() {
        recordsManagers       = [ZStorageMode : ZCloudManager]()
        manifestByStorageMode = [ZStorageMode : ZManifest] ()
    }


    func cancel() {
        currentCloudManager.currentOperation?.cancel()
    }

    func manifest(for mode: ZStorageMode) -> ZManifest {
        var manifest = manifestByStorageMode[mode]

        if  manifest == nil {
            let            manifestName = "manifest.\(mode.rawValue)"
            let    recordID: CKRecordID = CKRecordID(recordName: manifestName)
            let    record:   CKRecord   = CKRecord(recordType: kManifestType, recordID: recordID)
            manifest                    = ZManifest(record: record, storageMode: .mineMode) // every manifest gets stored in .mine
            manifest!     .manifestMode = mode
            manifestByStorageMode[mode] = manifest
        }

        return manifest!
    }


    func cloudManagerFor(_ storageMode: ZStorageMode) -> ZCloudManager {
        return recordsManagerFor(storageMode) as! ZCloudManager

    }

    func recordsManagerFor(_ storageMode: ZStorageMode?) -> ZRecordsManager? {
        if storageMode == nil {
            return nil
        }

        if storageMode == .favoritesMode {
            return gFavoritesManager
        }

        for storageMode in gAllDatabaseModes {
            if  recordsManagers[storageMode] == nil {
                recordsManagers[storageMode] = ZCloudManager(storageMode)
            }
        }

        return recordsManagers[storageMode!]!
    }


    func databaseForMode(_ mode: ZStorageMode) -> CKDatabase? {
        switch mode {
        case .everyoneMode: return gContainer.publicCloudDatabase
        case   .sharedMode: return gContainer.sharedCloudDatabase
        case     .mineMode: return gContainer.privateCloudDatabase
        default:            return nil
        }
    }


    func establishRoot(_ storageMode: ZStorageMode, _ onCompletion: IntClosure?) {
        switch storageMode {
        case .favoritesMode: onCompletion?(0)
        default:             cloudManagerFor(storageMode).establishRoot(onCompletion)
        }
    }


    func establishHere(_ iStorageMode: ZStorageMode, _ onCompletion: IntClosure?) {
        let manifest             = self.manifest(for: iStorageMode)
        let establishHereClosure = { self.cloudManagerFor(iStorageMode).establishHere(onCompletion) }

        if  iStorageMode         == .favoritesMode,
            let             root = gFavoritesManager.rootZone {
            manifest   .hereZone = root
        } else if manifest.here != nil {
            let             here = manifest.hereZone

            if  here    .record != nil,
                here  .zoneName != nil {
                here.maybeNeedChildren()
            } else {
                return establishHereClosure()
            }
        } else {
            return establishHereClosure()
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
        gContainer.accountStatus { (iStatus, iError) in
            if iStatus == .available {
                let badgeResetOperation = CKModifyBadgeOperation(badgeValue: 0)

                badgeResetOperation.modifyBadgeCompletionBlock = { (error) -> Void in
                    if error == nil {
                        FOREGROUND {
                            gApplication.clearBadge()
                        }
                    }
                }

                gContainer.add(badgeResetOperation)
            }
        }
    }


    // MARK:- receive from cloud
    // MARK:-


    func receivedUpdateFor(_ recordID: CKRecordID) {
        resetBadgeCounter()
        gCloudManager.assureRecordExists(withRecordID: recordID, recordType: kZoneType) { iUpdatedRecord in
            if iUpdatedRecord != nil {                                                   // TODO: extract storage mode from record id, i.e., the database
                let    zone = self.currentCloudManager.zoneForCKRecord(iUpdatedRecord!)  // TODO: currentCloudManager is wrong here
                zone.record = iUpdatedRecord
                let  parent = zone.parentZone

                if  zone.showChildren {
                    FOREGROUND {
                        self.signalFor(parent, regarding: .redraw)

                        gDBOperationsManager.children(.restore) { iSame in
                            self.signalFor(parent, regarding: .redraw)
                        }
                    }
                }
            }
        }
    }

}
