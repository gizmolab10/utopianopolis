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
var gEveryoneCloudManager : ZCloudManager? { return gRemoteStoresManager.cloudManager(for: .everyoneID) }
var     gMineCloudManager : ZCloudManager? { return gRemoteStoresManager.cloudManager(for: .mineID) }
var         gCloudManager : ZCloudManager? { return gRemoteStoresManager.currentCloudManager }
var         gLostAndFound : Zone?          { return gRemoteStoresManager.lostAndFoundZone }
var        gFavoritesRoot : Zone?          { return gMineCloudManager?.favoritesZone }
var                gTrash : Zone?          { return gRemoteStoresManager.trashZone }
var                 gRoot : Zone?    { get { return gRemoteStoresManager.rootZone } set { gRemoteStoresManager.rootZone  = newValue } }
var     gCloudUnavailable : Bool           { return gMineCloudManager?.cloudUnavailable ?? false }


class ZRemoteStoresManager: NSObject {


    var       databaseIDStack = [ZDatabaseID] ()
    var       recordsManagers = [ZDatabaseID : ZRecordsManager]()
    var currentRecordsManager : ZRecordsManager { return recordsManagerFor(gDatabaseID)! }
    var   currentCloudManager : ZCloudManager?  { return cloudManager(for: gDatabaseID) }
    var      rootProgenyCount : Int             { return (rootZone?.progenyCount ?? 0) + (rootZone?.count ?? 0) + 1 }
    var      lostAndFoundZone : Zone?           { return currentRecordsManager.lostAndFoundZone }
    var           destroyZone : Zone?           { return currentRecordsManager.destroyZone }
    var             trashZone : Zone?           { return currentRecordsManager.trashZone }
    var              rootZone : Zone?     { get { return currentRecordsManager.rootZone }  set { currentRecordsManager.rootZone  = newValue } }


    func cloudManager   (for dbID: ZDatabaseID) -> ZCloudManager? { return recordsManagerFor(dbID) as? ZCloudManager }
    func rootZone       (for dbID: ZDatabaseID) -> Zone?          { return recordsManagerFor(dbID)?.rootZone }
    func setRootZone(_ root: Zone?, for dbID: ZDatabaseID)        {        recordsManagerFor(dbID)?.rootZone = root }
    func clear()                                                  { recordsManagers = [ZDatabaseID : ZCloudManager] () }
    func cancel()                                                 { currentCloudManager?.currentOperation?.cancel()     }


    func recount() {  // all progenyCounts for all progeny in all databases in all roots
        for dbID in kAllDatabaseIDs {
            recordsManagerFor(dbID)?.recount()
        }
    }


    func updateLastSyncDates() {
        for dbID in kAllDatabaseIDs {
            recordsManagerFor(dbID)?.updateLastSyncDate()
        }
    }
    
    
    func saveAll() {
        for dbID in kAllDatabaseIDs {
            cloudManager(for: dbID)?.saveAll()
        }
    }
    

    func recordsManagerFor(_  iDatabaseID: ZDatabaseID?) -> ZRecordsManager? {
        var manager: ZRecordsManager?

        if  let dbID     =  iDatabaseID {
            manager      = recordsManagers[dbID]

            if  manager == nil {
                manager  = ZCloudManager(dbID)
                recordsManagers[dbID] = manager
            }
        }

        return manager
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


    func receivedUpdateFor(_ recordID: CKRecord.ID) {
        resetBadgeCounter()

        ////////////////////////////////////////////////////////////////////////////////////
        // BUG: record may be from the non-current cloud manager (i.e., != gCloudManager) //
        ////////////////////////////////////////////////////////////////////////////////////

        gCloudManager?.assureRecordExists(withRecordID: recordID, recordType: kZoneType) { iUpdatedRecord in
            if  let  record = iUpdatedRecord,                                     // TODO: extract database identifier from record id, i.e., the database
                let    zone = self.currentCloudManager?.zoneForCKRecord(record) { // TODO: currentCloudManager is wrong here
                zone.record = record
                let  parent = zone.parentZone

                if  zone.showingChildren {
                    FOREGROUND {
                        gControllers.signalFor(parent, regarding: .eRelayout)

                        gBatchManager.children(.restore) { iSame in
                            gControllers.signalFor(parent, regarding: .eRelayout)
                        }
                    }
                }
            }
        }
    }

}
