//
//  ZRemoteStorage.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/8/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


let gRemoteStorage = ZRemoteStorage()
var gEveryoneCloud : ZCloud?     { return gRemoteStorage.cloud(for: .everyoneID) }
var     gMineCloud : ZCloud?     { return gRemoteStorage.cloud(for: .mineID) }
var         gCloud : ZCloud?     { return gRemoteStorage.currentCloud }
var     gAllClouds : [ZCloud]    { return gRemoteStorage.allClouds }
var  gLostAndFound : Zone?       { return gRemoteStorage.lostAndFoundZone }
var         gTrash : Zone?       { return gRemoteStorage.trashZone }
var          gRoot : Zone? { get { return gRemoteStorage.rootZone } set { gRemoteStorage.rootZone  = newValue } }


class ZRemoteStorage: NSObject {


    var  databaseIDStack = [ZDatabaseID] ()
    var          records = [ZDatabaseID : ZRecords]()
    var   currentRecords : ZRecords    { return zRecords(for: gDatabaseID)! }
    var     currentCloud : ZCloud?     { return cloud   (for: gDatabaseID) }
    var rootProgenyCount : Int         { return (rootZone?.progenyCount ?? 0) + (rootZone?.count ?? 0) + 1 }
    var         manifest : ZManifest?  { return currentRecords.manifest }
    var lostAndFoundZone : Zone?       { return currentRecords.lostAndFoundZone }
    var      destroyZone : Zone?       { return currentRecords.destroyZone }
    var        trashZone : Zone?       { return currentRecords.trashZone }
    var         rootZone : Zone? { get { return currentRecords.rootZone }  set { currentRecords.rootZone  = newValue } }

    
    var allClouds: [ZCloud] {
        var clouds = [ZCloud] ()
        
        for dbID in kAllDatabaseIDs {
            if let cloud = cloud(for: dbID) {
                clouds.append(cloud)
            }
        }
        
        return clouds
    }
    
    
    var allRecordsArrays: [ZRecords] {
        var recordsArray = [ZRecords] ()
        
        for dbID in kAllDatabaseIDs {
            if  let records = zRecords(for: dbID) {
                recordsArray.append(records)
            }
        }
        
        return recordsArray
    }
    
    func cloud(for dbID: ZDatabaseID) -> ZCloud? { return zRecords(for: dbID) as? ZCloud }
    func clear()                                 { records =    [ZDatabaseID  :   ZCloud] () }
    func cancel()                                { currentCloud?.currentOperation?.cancel() }

    func recount() {  // all progenyCounts for all progeny in all databases in all roots
        for records in allRecordsArrays {
            records.recount()
        }
    }

    func updateLastSyncDates() {
        for records in allRecordsArrays {
            records.updateLastSyncDate()
        }
    }
    
    func updateNeededCounts() {
        for cloud in allClouds {
            var alsoProgenyCounts = false
            cloud.fullUpdate(for: [.needsCount]) { state, iZRecord in
                if  let zone                 = iZRecord as? Zone {
                    if  zone.fetchableCount != zone.count {
                        zone.fetchableCount  = zone.count
                        alsoProgenyCounts    = true
                        
                        zone.maybeNeedSave()
                    }
                }
            }
            
            if  alsoProgenyCounts {
                cloud.rootZone?.updateAllProgenyCounts()
            }
        }
	}

	func adoptAll(moveOrphansToLost: Bool = false) {
		for cloud in allClouds {
			cloud.adoptAll(moveOrphansToLost: moveOrphansToLost)
		}
	}

	func maybeZoneForRecordName (_ iRecordName: String?) -> Zone? {
		if  let name = iRecordName {
			for cloud in allClouds {
				if  let    zone = cloud.maybeZoneForRecordName(name) {
					return zone
				}
			}
		}

		return nil
	}

    func zRecords(for iDatabaseID: ZDatabaseID?) -> ZRecords? {
        var zRecords: ZRecords?

        if  let dbID          =  iDatabaseID {
            zRecords          = records[dbID]
            if  zRecords     == nil {
                zRecords      = ZCloud(dbID)
                records[dbID] = zRecords
            }
        }

        return zRecords
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
        if  gCloudAccountStatus == .active {
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
    

    func receiveFromCloud(_ notification: CKQueryNotification) {
        resetBadgeCounter()

		FOREGROUND {
			if  let     dbID = ZDatabaseID.convert(from: notification.databaseScope),
				let    cloud = self.cloud(for: dbID),
				let recordID = notification.recordID {
				let      dbi = dbID.indicator
				let ckRecord = cloud.maybeCKRecordForRecordName(recordID.recordName)
				let     name = (ckRecord?["zoneName"] as String?) ?? kUnknown
				let     type = ckRecord?.recordType   as String?  ?? kUnknown

				if  type == kUnknown, ckRecord != nil {
					print("received a record from cloud kit, with an unknown type: \(ckRecord!.recordType)")
				}

				switch (notification.queryNotificationReason) {
					case .recordCreated,
						 .recordUpdated:
						cloud.addCKRecord(ckRecord, for: [.needsFetch])
						printDebug(.dRemote, "receiving \(dbi) \"\(type)\" \(name)")
						self.redrawAndSyncAndRedraw()
					case .recordDeleted:
						if  let deleted = cloud.maybeZoneForCKRecord(ckRecord) {
							printDebug(.dRemote, "deleted \(dbi) \(name)")
							[deleted].deleteZones(permanently: true) {
								self.redrawAndSyncAndRedraw()
							}
						}
				}
			}
		}
    }

}
