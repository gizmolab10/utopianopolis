//
//  ZManifest.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/24/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

var gManifest: ZManifest? { return gRecords?.manifest }

@objc(ZManifest)
class ZManifest : ZRecord {
    
    class ZDeleted: NSObject {
        
        var name: String?

        init(with iName: String) {
            name = iName
        }

    }

	var zDeleted = [ZDeleted]()
    @NSManaged var deletedRecordNames: [String]?
	override var cloudProperties: [String] { return ZManifest.cloudProperties }
	override class var cloudProperties: [String] { return super.cloudProperties + [#keyPath(deletedRecordNames)] }
	override func ignoreKeyPathsForStorage() -> [String] { return super.ignoreKeyPathsForStorage() + [#keyPath(deletedRecordNames)] }

    var updatedRefs: [String]? {
        if  let d = deletedRecordNames {                 // FIRST: merge deleted into zDeleted
            for ref in d {
                smartAppend(ref)
            }
        }

        let zCount = zDeleted.count
        let dCount = deletedRecordNames?.count ?? 0

        if  zCount > 0, zCount != dCount {    // SECOND: update deleted if count does not match zDeleted
			deletedRecordNames = []
            
            // create deleted from zDeleted
            for zd in zDeleted {
                if  let s = zd.name {
					deletedRecordNames?.append(s)
                }
            }
        }

        return deletedRecordNames
    }

    func apply() {
        for deleteMe in zDeleted {
            if  let      name = deleteMe.name {
                let   records = gRemoteStorage.cloud(for: databaseID)
                if  let  zone = records?.maybeZRecordForRecordName(name) as? Zone,
                    let trash = records?.trashZone {
                    zone.orphan()
                    trash.addChild(zone)
                }
            }
        }
    }
    
    @discardableResult func smartAppend(_ iItem: Any) -> Bool {
        let refString  = iItem as? String
        let zRecord    = iItem as? ZRecord
        var zd         = iItem as? ZDeleted
        var name       = zd?.name ?? zRecord?.recordName

        if  let     s  = refString {
            zd         = ZDeleted(with: s)
            name       = zd?.name
        }

        if  let     n  = name {
            for ref in zDeleted {
                if  n == ref.name {
                    return false // already there, do not add (a duplicate)
                }
            }
            
            if  zd == nil {
                zd  = ZDeleted(with: n)
            }
            
            zDeleted.append(zd!)
            
            return true
        }

        return false
	}

	static func uniqueManifest(recordName: String?, in dbID: ZDatabaseID) -> ZManifest {
		return uniqueZRecord(entityName: kManifestType, recordName: recordName, in: dbID) as! ZManifest
	}

	static func uniqueManifest(from dict: ZStorageDictionary, in dbID: ZDatabaseID) -> ZManifest? {
		let result = uniqueManifest(recordName: dict.recordName, in: dbID)

		result.temporarilyIgnoreNeeds {
			do {
				try result.extractFromStorageDictionary(dict, of: kManifestType, into: dbID)
			} catch {
				printDebug(.dError, "\(error)")    // de-serialization
			}
		}

		return result
	}

    override func extractFromStorageDictionary(_ dict: ZStorageDictionary, of iRecordType: String, into iDatabaseID: ZDatabaseID) throws {
        try super.extractFromStorageDictionary(dict, of: iRecordType, into: iDatabaseID)
        
        if  let deletedsArray = dict[.deleted] as? [ZStorageDictionary] {
            for d in deletedsArray {
                cloud?.temporarilyIgnoreAllNeeds() { // prevent needsSave caused by child's parent (intentionally) not being in childDict
                    self.smartAppend(d)
                }
            }
        }
    }
    
    override func createStorageDictionary(for iDatabaseID: ZDatabaseID, includeRecordName: Bool = true, includeInvisibles: Bool = true, includeAncestors: Bool = false) throws -> ZStorageDictionary? {
		var dict           = try super.createStorageDictionary(for: iDatabaseID, includeRecordName: includeRecordName, includeInvisibles: includeInvisibles, includeAncestors: includeAncestors) ?? ZStorageDictionary ()
        
        if  let          d = updatedRefs as NSObject? {
            dict[.deleted] = d
        }

        return dict
    }

}
