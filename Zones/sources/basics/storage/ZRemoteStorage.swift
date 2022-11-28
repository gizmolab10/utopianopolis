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
var gEveryoneCloud : ZCloud?     { return gRemoteStorage.zRecords(for: .everyoneID) as? ZCloud }
var     gMineCloud : ZCloud?     { return gRemoteStorage.zRecords(for:     .mineID) as? ZCloud }
var         gCloud : ZCloud?     { return gRemoteStorage.currentCloud }
var     gAllClouds : [ZCloud]    { return gRemoteStorage.allClouds }
var  gLostAndFound : Zone?       { return gRemoteStorage.lostAndFoundZone }
var       gDestroy : Zone?       { return gRemoteStorage.destroyZone }
var         gTrash : Zone?       { return gRemoteStorage.trashZone }
var          gRoot : Zone? { get { return gRemoteStorage.rootZone } set { gRemoteStorage.rootZone  = newValue } }

func gRecountMaybe() {
	if  gNeedsRecount {
		gNeedsRecount = false

		gRemoteStorage.recount()
		gSignal([.spDataDetails])
	}
}

class ZRemoteStorage: NSObject {

    var  databaseIDStack = [ZDatabaseID] ()
    var          records = [ZDatabaseID : ZRecords]()
    var   currentRecords : ZRecords    { return zRecords(for: gDatabaseID)! }
    var     currentCloud : ZCloud?     { return currentRecords as? ZCloud }
    var rootProgenyCount : Int         { return (rootZone?.progenyCount ?? 0) + (rootZone?.count ?? 0) + 1 }
	var         manifest : ZManifest?  { return currentRecords.manifest }
    var lostAndFoundZone : Zone?       { return currentRecords.lostAndFoundZone }
    var      destroyZone : Zone?       { return currentRecords.destroyZone }
    var        trashZone : Zone?       { return currentRecords.trashZone }
	var         rootZone : Zone? { get { return currentRecords.rootZone }  set { currentRecords.rootZone  = newValue } }
	func cloud(for dbID: ZDatabaseID) -> ZCloud? { return zRecords(for: dbID) as? ZCloud }
	func clear()                                 { records =       [ZDatabaseID : ZCloud] () }
	func cancel()                                { currentCloud?.currentOperation?.cancel() }

	var allProgeny : ZoneArray {
		var total = ZoneArray()

		for cloud in allClouds {
			total.append(contentsOf: cloud.allProgeny)
		}

		return total
	}

	var count: Int {
		var sum = 0
		for dbID in kAllDatabaseIDs {
			if let zRecords = zRecords(for: dbID) {
				sum += zRecords.zRecordsLookup.count
			}
		}

		return sum
	}

	var totalManifestCount: Int {
		var sum = 0
		for cloud in allClouds {
			sum += cloud.manifest?.count?.intValue ?? 0
		}

		return sum
	}

	var totalRecordsCount: Int {
		var count = 0

		for cloud in allClouds {
			count += cloud.zRecordsCount
		}

		return count
	}

	var totalLoadableRecordsCount: Int {
		switch gCDMigrationState {
			case .normal: return totalManifestCount
			default:      return gFiles.migrationFilesSize / kFileRecordSize
		}
	}

	var countStatus : String {
		let rCount = totalRecordsCount
		let lCount = totalLoadableRecordsCount
		let suffix = lCount == 0 ? kEmpty :  " (of \(lCount))"

		return "\(rCount)" + suffix
	}

    var allClouds: [ZCloud] {
        var clouds = [ZCloud] ()
        
        for dbID in kAllDatabaseIDs {
            if  let cloud = zRecords(for: dbID) as? ZCloud {
                clouds.append(cloud)
            }
        }
        
        return clouds
    }

    var allRecordsArrays:  [ZRecords] {
        var recordsArray = [ZRecords] ()
        
        for dbID in kAllDatabaseIDs {
            if  let records = zRecords(for: dbID) {
                recordsArray.append(records)
            }
        }
        
        return recordsArray
    }

	func updateAllManifestCounts() {
		for dbID in kAllDatabaseIDs {
			updateManifestCount(for: dbID)
		}
	}

	func updateManifestCount(for  dbID: ZDatabaseID) {
		if  let r = zRecords(for: dbID) {
		    let c = r.zRecordsCount
			r.manifest?.count = NSNumber(value: c)
		}
	}

	func removeAllDuplicates() {
		for records in allRecordsArrays {
			records.removeAllDuplicates()
		}
	}

	func setup() {
		updateRootsOfAllProjeny()
		updateAllManifestCounts()
		recount()
	}

    func recount() {  // all progenyCounts for all progeny in all databases in all roots
        for cloud in allClouds {
			cloud.recount()
        }
    }

	func updateRootsOfAllProjeny() {
		for cloud in allClouds {
			cloud.updateRootsOfAllProjeny()
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
                    }
                }
            }
            
            if  alsoProgenyCounts {
                cloud.rootZone?.updateAllProgenyCounts()
            }
        }
	}

	func updateAllInstanceProperties() {
		var fixed = 0
		var  lost = 0

		for cloud in allClouds {
			(fixed, lost) = cloud.updateAllInstanceProperties(fixed, lost)
		}

		print("fixed: \(fixed) lost: \(lost)")
	}

	func assureAdoption() {
		for cloud in allClouds {
			cloud.assureAdoption()
		}
	}

	func adoptAllNeedingAdoption() {
		for cloud in allClouds {
			let remaining = cloud.adoptAllNeedingAdoption()
			if  remaining > 0 {
				printDebug(.dAdopt, "unadopted: \(remaining)")
			}
		}
	}

	func maybeZRecordForRecordName (_ iRecordName: String?) -> ZRecord? {
		if  let name = iRecordName {
			for cloud in allClouds {
				if  let    zRecord = cloud.maybeZRecordForRecordName(name) {
					return zRecord
				}
			}
		}

		return nil
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
		let dbID          = iDatabaseID ?? gDatabaseID
		var zRecords      = records[dbID]
		if  zRecords     == nil {
			switch dbID {
			case .favoritesID: zRecords = gFavorites
//			case .recentsID:   zRecords = gRecents
			default:           zRecords = ZCloud(dbID)
			}
			
			records[dbID] = zRecords
		}

        return zRecords
    }


    func databaseForID(_ iID: ZDatabaseID) -> CKDatabase? {
        switch iID {
        case .everyoneID: return gContainer .publicCloudDatabase
        case     .mineID: return gContainer.privateCloudDatabase
        default:          return nil
        }
    }


    func pushDatabaseID(_ dbID: ZDatabaseID?) {
		if  let d = dbID {
			databaseIDStack.append(gDatabaseID)

			gDatabaseID = d
		}
	}


    func popDatabaseID() {
        if  databaseIDStack.count > 0,
			let    dbID = databaseIDStack.popLast() {
            gDatabaseID = dbID
        }
    }


//    func resetBadgeCounter() {
//        if  gCloudAccountStatus == .active {
//            let badgeResetOperation = CKModifyBadgeOperation(badgeValue: 0)
//
//            badgeResetOperation.modifyBadgeCompletionBlock = { (error) -> Void in
//                if error == nil {
//                    FOREGROUND {
//                        gApplication?.clearBadge()
//                    }
//                }
//            }
//
//            gContainer.add(badgeResetOperation)
//        }
//    }

}
