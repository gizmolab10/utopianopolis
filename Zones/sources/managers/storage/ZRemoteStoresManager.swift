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


var gAllRegisteredZRecords: [ZRecord] {
    var records = [ZRecord] ()

    for mode in gAllDatabaseModes {
        let manageer = gRemoteStoresManager.cloudManagerFor(mode)
        records     += manageer.zRecordsByID.values
    }

    return records
}


class ZRemoteStoresManager: NSObject {


    var      storageModeStack = ZModes ()
    var       recordsManagers = [ZStorageMode : ZCloudManager]()
    var manifestByStorageMode = [ZStorageMode : ZManifest] ()
    var currentRecordsManager: ZRecordsManager { return recordsManagerFor(gStorageMode)! }
    var   currentCloudManager: ZCloudManager   { return cloudManagerFor(gStorageMode) }
    var      rootProgenyCount: Int             { return (rootZone?.progenyCount ?? 0) + (rootZone?.count ?? 0) + 1 }
    var              manifest: ZManifest       { return manifest(for: gStorageMode) }
    var             trashZone: Zone?     { get { return currentRecordsManager.trashZone } set { currentRecordsManager.trashZone = newValue } }
    var              rootZone: Zone?     { get { return currentRecordsManager.rootZone }  set { currentRecordsManager.rootZone  = newValue } }


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
            let    record:   CKRecord   = CKRecord(recordType: gManifestTypeKey, recordID: recordID)
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
    

    func applyToAllZones(in modes: ZModes, _ closure: ZoneClosure) {
        for mode: ZStorageMode in modes {
            let zRecords = cloudManagerFor(mode).zRecordsByID

            for zRecord in zRecords.values {
                if let zone = zRecord as? Zone {
                    closure(zone)
                }
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
        gCloudManager.assureRecordExists(withRecordID: recordID, recordType: gZoneTypeKey) { iRecord in
            if iRecord != nil {                                                 // TODO: extract storage mode from record id, i.e., the database
                let    zone = self.currentCloudManager.zoneForRecord(iRecord!)  // TODO: currentCloudManager is wrong here
                zone.record = iRecord
                let  parent = zone.parentZone

                if  zone.showChildren {
                    FOREGROUND {
                        self.signalFor(parent, regarding: .redraw)

                        gDBOperationsManager.children(.restore) {
                            self.signalFor(parent, regarding: .redraw)
                        }
                    }
                }
            }
        }
    }

}
