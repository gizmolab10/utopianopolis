//
//  ZManifest.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/24/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

var gManifest: ZManifest? { return gRecords.manifest }

@objc(ZManifest)
class ZManifest : ZRecord {
    
    class ZDeleted: NSObject {
        
        var name: String?

        init(with iName: String) {
            name = iName
        }

    }

	var zDeleted = [ZDeleted]()
	@NSManaged var count: NSNumber?
	@NSManaged var deletedRecordNames: StringsArray?
	override var cloudProperties: StringsArray { return ZManifest.cloudProperties }
	override class var cloudProperties: StringsArray { return super.cloudProperties + [#keyPath(deletedRecordNames), #keyPath(count)] }
//	override func ignoreKeyPathsForStorage() -> StringsArray { return super.ignoreKeyPathsForStorage() + [#keyPath(deletedRecordNames)] }

    var updatedRefs: StringsArray? {
        if  let d = deletedRecordNames {                 // FIRST: merge deleted into zDeleted
            for ref in d {
                smartAppend(ref)
            }
        }

        let zCount = zDeleted.count
        let dCount = deletedRecordNames?.count ?? 0

        if  zCount > 0, zCount != dCount {    // SECOND: update deleted if count does not match zDeleted
			updateDeletedList()
        }

        return deletedRecordNames
    }

	func updateDeletedList() {
		deletedRecordNames = StringsArray()

		for zd in zDeleted {       // create deleted from zDeleted
			if  let s = zd.name {
				deletedRecordNames?.append(s)
			}
		}
	}

    func applyDeleted() {
        for deleteMe in zDeleted {
            if  let      name = deleteMe.name {
                let   records = gRemoteStorage.zRecords(for: databaseID)
                if  let  zone = records?.maybeZRecordForRecordName(name) as? Zone,
                    let trash = records?.trashZone {
                    zone.orphan()
                    trash.addChildNoDuplicate(zone)
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

	static func uniqueManifest(recordName: String?, in databaseID: ZDatabaseID) -> ZManifest {
		return uniqueZRecord(entityName: kManifestType, recordName: recordName, in: databaseID) as! ZManifest
	}

	static func uniqueManifest(from dict: ZStorageDictionary, in databaseID: ZDatabaseID) -> ZManifest? {
		let result = uniqueManifest(recordName: dict.recordName, in: databaseID)

		result.temporarilyIgnoreNeeds {
			do {
				try result.extractFromStorageDictionary(dict, of: kManifestType, into: databaseID)
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
				zRecords?.temporarilyIgnoreAllNeeds() { // prevent needsSave caused by child's parent (intentionally) not being in childDict
                    smartAppend(d)
                }
            }
        }
    }
    
    override func createStorageDictionary(for iDatabaseID: ZDatabaseID, includeRecordName: Bool = true, includeInvisibles: Bool = true, includeAncestors: Bool = false) throws -> ZStorageDictionary? {
		var dict           = try super.createStorageDictionary(for: iDatabaseID, includeRecordName: includeRecordName, includeInvisibles: includeInvisibles, includeAncestors: includeAncestors) ?? ZStorageDictionary ()
        
        if  let          d = deletedRecordNames as NSObject? {
            dict[.deleted] = d
        }

        return dict
    }

}
