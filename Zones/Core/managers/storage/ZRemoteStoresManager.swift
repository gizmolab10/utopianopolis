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
var         gHere: Zone    { get { return gManifest.hereZone }            set { gManifest.hereZone      = newValue } }
var         gRoot: Zone?   { get { return gRemoteStoresManager.rootZone } set { gRemoteStoresManager.rootZone = newValue } }


class ZRemoteStoresManager: NSObject {


    let             container = CKContainer(identifier: cloudID)
    var      storageModeStack = [ZStorageMode] ()
    var       recordsManagers = [ZStorageMode : ZCloudManager]()
    var manifestByStorageMode = [ZStorageMode : ZManifest] ()
    var currentRecordsManager: ZRecordsManager { return recordsManagerFor(gStorageMode) }
    var   currentCloudManager: ZCloudManager   { return cloudManagerFor(gStorageMode) }
    var      rootProgenyCount: Int             { return hasRootZone ? rootZone!.progenyCount : 0 }
    var           hasRootZone: Bool            { return rootZone != nil }
    var              manifest: ZManifest       { return manifest(for: gStorageMode) }
    var              rootZone: Zone?     { get { return currentRecordsManager.rootZone } set { currentRecordsManager.rootZone = newValue } }


    func rootZone(for mode: ZStorageMode) -> Zone? { return recordsManagerFor(mode).rootZone }


    func manifest(for mode: ZStorageMode) -> ZManifest {
        var manifest = manifestByStorageMode[mode]

        if  manifest == nil {
            let            manifestName = manifestNameForMode(mode)
            let    recordID: CKRecordID = CKRecordID(recordName: manifestName)
            let    record:   CKRecord   = CKRecord(recordType: manifestTypeKey, recordID: recordID)
            manifest                    = ZManifest(record: record, storageMode: .mine) // every manifest gets stored in .mine
            manifest!     .manifestMode = mode
            manifestByStorageMode[mode] = manifest
        }

        return manifest!
    }


    func cloudManagerFor(_ storageMode: ZStorageMode) -> ZCloudManager {
        return recordsManagerFor(storageMode) as! ZCloudManager
    }


    func recordsManagerFor(_ storageMode: ZStorageMode) -> ZRecordsManager {
        if storageMode == .favorites {
            return gFavoritesManager
        }

        for storageMode in [ZStorageMode.everyone, ZStorageMode.mine] {
            if  recordsManagers[storageMode] == nil {
                recordsManagers[storageMode] = ZCloudManager(storageMode)
            }
        }

        return recordsManagers[storageMode]!
    }


    func databaseForMode(_ mode: ZStorageMode) -> CKDatabase? {
        switch mode {
        case .everyone: return container.publicCloudDatabase
        case .shared:   return container.sharedCloudDatabase
        case .mine:     return container.privateCloudDatabase
        default:        return nil
        }
    }
    

    func establishRoot(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        switch storageMode {
        case .favorites: onCompletion?(0)
        default:         cloudManagerFor(storageMode).establishRoot(onCompletion)
        }
    }


    func establishHere(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let manifest = self.manifest(for: storageMode)
        let     here = manifest.hereZone

        if storageMode == .favorites {
            manifest.hereZone = gFavoritesManager.rootZone!
        } else if here.record != nil && here.zoneName != nil {
            here.maybeNeedChildren()
            here.needFetch()
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
        if storageModeStack.count != 0, let mode = storageModeStack.popLast() {
            gStorageMode = mode
        }
    }


    func resetBadgeCounter() {
        container.accountStatus { (iStatus, iError) in
            if iStatus == .available {
                let badgeResetOperation = CKModifyBadgeOperation(badgeValue: 0)

                badgeResetOperation.modifyBadgeCompletionBlock = { (error) -> Void in
                    if error == nil {
                        zapplication.clearBadge()
                    }
                }

                self.container.add(badgeResetOperation)
            }
        }
    }
    

    func applyToAllZones(in modes: [ZStorageMode], _ closure: ZoneClosure) {
        for mode: ZStorageMode in modes {
            let cloud = cloudManagerFor(mode)
            let zones = cloud.zonesByID

            for zone in zones.values {
                closure(zone)
            }
        }
    }


    func bookmarksFor(_ zone: Zone?) -> [Zone] {
        var zoneBookmarks = [Zone] ()

        if zone != nil, let recordID = zone?.record?.recordID {
            applyToAllZones(in: [.mine, .everyone]) { iZone in
                if let link = iZone.crossLink, recordID == link.record?.recordID {
                    zoneBookmarks.append(iZone)
                }
            }
        }

        return zoneBookmarks
    }
    

    // MARK:- receive from cloud
    // MARK:-


    // TODO extract storage mode from record id (?)
    // i.e., the database
    // TODO: currentCloudManager is wrong here

    func receivedUpdateFor(_ recordID: CKRecordID) {
        resetBadgeCounter()
        currentCloudManager.assureRecordExists(withRecordID: recordID, recordType: zoneTypeKey) { iRecord in
            if iRecord != nil {
                // get from the record id's cloud zone
                let    zone = self.currentCloudManager.zoneForRecord(iRecord!)
                zone.record = iRecord
                let  parent = zone.parentZone

                if  zone.showChildren {
                    self.dispatchAsyncInForeground {
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