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
var               gTrash : Zone?         { return gRemoteStoresManager.trashZone }
var                gRoot : Zone?   { get { return gRemoteStoresManager.rootZone } set { gRemoteStoresManager.rootZone  = newValue } }


class ZRemoteStoresManager: NSObject {


    var      databaseiDStack = ZDatabaseiDs ()
    var       recordsManagers = [ZDatabaseiD : ZCloudManager]()
    var currentRecordsManager: ZRecordsManager { return recordsManagerFor(gDatabaseiD)! }
    var   currentCloudManager: ZCloudManager   { return cloudManagerFor(gDatabaseiD) }
    var      rootProgenyCount: Int             { return (rootZone?.progenyCount ?? 0) + (rootZone?.count ?? 0) + 1 }
    var      lostAndFoundZone: Zone?           { return currentRecordsManager.lostAndFoundZone }
    var             trashZone: Zone?           { return currentRecordsManager.trashZone }
    var              rootZone: Zone?     { get { return currentRecordsManager.rootZone }  set { currentRecordsManager.rootZone  = newValue } }


    func rootZone(for dbID: ZDatabaseiD) -> Zone? { return recordsManagerFor(dbID)?.rootZone }


    func clear() {
        recordsManagers = [ZDatabaseiD : ZCloudManager]()
    }


    func cancel() {
        currentCloudManager.currentOperation?.cancel()
    }


    func cloudManagerFor(_ databaseiD: ZDatabaseiD) -> ZCloudManager {
        return recordsManagerFor(databaseiD) as! ZCloudManager

    }


    func recordsManagerFor(_ databaseiD: ZDatabaseiD?) -> ZRecordsManager? {
        if databaseiD == nil {
            return nil
        }

        if databaseiD == .favoritesID {
            return gFavoritesManager
        }

        for databaseiD in gAllDatabaseiDs {
            if  recordsManagers[databaseiD] == nil {
                recordsManagers[databaseiD] = ZCloudManager(databaseiD)
            }
        }

        return recordsManagers[databaseiD!]!
    }


    func databaseForID(_ iID: ZDatabaseiD) -> CKDatabase? {
        switch iID {
        case .everyoneID: return gContainer.publicCloudDatabase
        case   .sharedID: return gContainer.sharedCloudDatabase
        case     .mineID: return gContainer.privateCloudDatabase
        default:          return nil
        }
    }


    func establishRoot(_ databaseiD: ZDatabaseiD, _ onCompletion: IntClosure?) {
        if !kFullFetch && databaseiD == .favoritesID {
            onCompletion?(0)
        } else {
            cloudManagerFor(databaseiD).establishRoot(onCompletion)
        }
    }


    func pushDatabaseID(_ dbID: ZDatabaseiD) {
        databaseiDStack.append(gDatabaseiD)

        gDatabaseiD = dbID
    }


    func popDatabaseID() {
        if databaseiDStack.count > 0, let dbID = databaseiDStack.popLast() {
            gDatabaseiD = dbID
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
            if iUpdatedRecord != nil {                                                   // TODO: extract database identifier from record id, i.e., the database
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
