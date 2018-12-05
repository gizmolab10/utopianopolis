//
//  ZRemoteStorage.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 5/8/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


let    gRemoteStorage = ZRemoteStorage()
var    gEveryoneCloud : ZCloud?     { return gRemoteStorage.cloud(for: .everyoneID) }
var        gMineCloud : ZCloud?     { return gRemoteStorage.cloud(for: .mineID) }
var            gCloud : ZCloud?     { return gRemoteStorage.currentCloud }
var     gLostAndFound : Zone?       { return gRemoteStorage.lostAndFoundZone }
var    gFavoritesRoot : Zone?       { return gMineCloud?.favoritesZone }
var            gTrash : Zone?       { return gRemoteStorage.trashZone }
var             gRoot : Zone? { get { return gRemoteStorage.rootZone } set { gRemoteStorage.rootZone  = newValue } }
var gCloudUnavailable : Bool        { return gMineCloud?.cloudUnavailable ?? false }


class ZRemoteStorage: NSObject {


    var  databaseIDStack = [ZDatabaseID] ()
    var         recordss = [ZDatabaseID : ZRecords]()
    var   currentRecords : ZRecords    { return recordsFor(gDatabaseID)! }
    var     currentCloud : ZCloud?     { return cloud(for: gDatabaseID) }
    var rootProgenyCount : Int         { return (rootZone?.progenyCount ?? 0) + (rootZone?.count ?? 0) + 1 }
    var lostAndFoundZone : Zone?       { return currentRecords.lostAndFoundZone }
    var      destroyZone : Zone?       { return currentRecords.destroyZone }
    var        trashZone : Zone?       { return currentRecords.trashZone }
    var         rootZone : Zone? { get { return currentRecords.rootZone }  set { currentRecords.rootZone  = newValue } }


    func cloud   (for dbID: ZDatabaseID) -> ZCloud?        { return recordsFor(dbID) as? ZCloud }
    func rootZone       (for dbID: ZDatabaseID) -> Zone?   { return recordsFor(dbID)?.rootZone }
    func setRootZone(_ root: Zone?, for dbID: ZDatabaseID) {        recordsFor(dbID)?.rootZone = root }
    func clear()                                           { recordss = [ZDatabaseID : ZCloud] () }
    func cancel()                                          { currentCloud?.currentOperation?.cancel()     }


    func recount() {  // all progenyCounts for all progeny in all databases in all roots
        for dbID in kAllDatabaseIDs {
            recordsFor(dbID)?.recount()
        }
    }


    func updateLastSyncDates() {
        for dbID in kAllDatabaseIDs {
            recordsFor(dbID)?.updateLastSyncDate()
        }
    }
    
    
    func saveAll() {
        for dbID in kAllDatabaseIDs {
            cloud(for: dbID)?.saveAll()
        }
    }
    

    func recordsFor(_  iDatabaseID: ZDatabaseID?) -> ZRecords? {
        var manager: ZRecords?

        if  let dbID     =  iDatabaseID {
            manager      = recordss[dbID]

            if  manager == nil {
                manager  = ZCloud(dbID)
                recordss[dbID] = manager
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
        // BUG: record may be from the non-current cloud manager (i.e., != gCloud) //
        ////////////////////////////////////////////////////////////////////////////////////

        gCloud?.assureRecordExists(withRecordID: recordID, recordType: kZoneType) { iUpdatedRecord in
            if  let  record = iUpdatedRecord,                                     // TODO: extract database identifier from record id, i.e., the database
                let    zone = self.currentCloud?.zoneForCKRecord(record) { // TODO: currentCloud is wrong here
                zone.record = record
                let  parent = zone.parentZone

                if  zone.showingChildren {
                    FOREGROUND {
                        gControllers.signalFor(parent, regarding: .eRelayout)

                        gBatches.children(.restore) { iSame in
                            gControllers.signalFor(parent, regarding: .eRelayout)
                        }
                    }
                }
            }
        }
    }

}
