//
//  ZRemoteStoresManager.swift
//  Zones
//
//  Created by Jonathan Sand on 5/8/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
import CloudKit


let  gRemoteStoresManager = ZRemoteStoresManager()
var gEveryoneCloudManager : ZCloudManager { return gRemoteStoresManager.cloudManagerFor(.everyoneID) }
var     gMineCloudManager : ZCloudManager { return gRemoteStoresManager.cloudManagerFor(.mineID) }
var         gCloudManager : ZCloudManager { return gRemoteStoresManager.currentCloudManager }
var         gLostAndFound : Zone?         { return gRemoteStoresManager.lostAndFoundZone }
var                gTrash : Zone?         { return gRemoteStoresManager.trashZone }
var                 gRoot : Zone?   { get { return gRemoteStoresManager.rootZone } set { gRemoteStoresManager.rootZone  = newValue } }


class ZRemoteStoresManager: NSObject {


    var       databaseIDStack = [ZDatabaseID] ()
    var       recordsManagers = [ZDatabaseID : ZCloudManager]()
    var currentRecordsManager : ZRecordsManager { return recordsManagerFor(gDatabaseID)! }
    var   currentCloudManager : ZCloudManager   { return cloudManagerFor(gDatabaseID) }
    var      rootProgenyCount : Int             { return (rootZone?.progenyCount ?? 0) + (rootZone?.count ?? 0) + 1 }
    var      lostAndFoundZone : Zone?           { return currentRecordsManager.lostAndFoundZone }
    var             trashZone : Zone?           { return currentRecordsManager.trashZone }
    var              rootZone : Zone?     { get { return currentRecordsManager.rootZone }  set { currentRecordsManager.rootZone  = newValue } }


    func cloudManagerFor(_   dbID: ZDatabaseID) -> ZCloudManager { return recordsManagerFor(dbID) as! ZCloudManager }
    func rootZone       (for dbID: ZDatabaseID) -> Zone?         { return recordsManagerFor(dbID)?.rootZone }
    func setRootZone(_ root: Zone?, for dbID: ZDatabaseID)       {        recordsManagerFor(dbID)?.rootZone = root }
    func clear()                                                 { recordsManagers = [ZDatabaseID : ZCloudManager] () }
    func cancel()                                                { currentCloudManager.currentOperation?.cancel()     }


    func updateLastSyncDates() {
        for dbID in kAllDatabaseIDs {
            if let manager = recordsManagerFor(dbID) {
                manager.updateLastSyncDate()
            }
        }
    }
    

    func recordsManagerFor(_ databaseID: ZDatabaseID?) -> ZRecordsManager? {
        if databaseID == nil {
            return nil
        }

        if databaseID == .favoritesID {
            return nil
        }

        for databaseID in kAllDatabaseIDs {
            if  recordsManagers[databaseID] == nil {
                recordsManagers[databaseID] = ZCloudManager(databaseID)
            }
        }

        return recordsManagers[databaseID!]!
    }


    func databaseForID(_ iID: ZDatabaseID) -> CKDatabase? {
        switch iID {
        case .everyoneID: return gContainer.publicCloudDatabase
        case   .sharedID: return gContainer.sharedCloudDatabase
        case     .mineID: return gContainer.privateCloudDatabase
        default:          return nil
        }
    }


    func pushDatabaseID(_ dbID: ZDatabaseID) {
        databaseIDStack.append(gDatabaseID)

        gDatabaseID = dbID
    }


    func popDatabaseID() {
        if databaseIDStack.count > 0, let dbID = databaseIDStack.popLast() {
            gDatabaseID = dbID
        }
    }


    func resetBadgeCounter() {
        if  gCloudAccountStatus == .available {
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


    // MARK:- receive from cloud
    // MARK:-


    func receivedUpdateFor(_ recordID: CKRecordID) {
        resetBadgeCounter()

        ////////////////////////////////////////////////////////////////////////////////////
        // BUG: record may be from the non-current cloud manager (i.e., != gCloudManager) //
        ////////////////////////////////////////////////////////////////////////////////////

        gCloudManager.assureRecordExists(withRecordID: recordID, recordType: kZoneType) { iUpdatedRecord in
            if iUpdatedRecord != nil {                                                   // TODO: extract database identifier from record id, i.e., the database
                let    zone = self.currentCloudManager.zoneForCKRecord(iUpdatedRecord!)  // TODO: currentCloudManager is wrong here
                zone.record = iUpdatedRecord
                let  parent = zone.parentZone

                if  zone.showChildren {
                    FOREGROUND {
                        self.signalFor(parent, regarding: .redraw)

                        gBatchManager.children(.restore) { iSame in
                            self.signalFor(parent, regarding: .redraw)
                        }
                    }
                }
            }
        }
    }

}
