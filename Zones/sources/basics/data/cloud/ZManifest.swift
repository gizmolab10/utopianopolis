//
//  ZManifest.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/24/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

var gManifest: ZManifest? { return gCloud?.manifest }

class ZManifest: ZRecord {
    
    class ZDeleted: NSObject {
        
        var name: String?
        var date: Date?
        var string: String? { if let n = name, let d = date { return ZDeleted.string(with: n, date: d) } else { return nil } }
        class func string(with iName: String, date iDate: Date) -> String? { return iName + kColonSeparator + "\(iDate.timeIntervalSince1970)" }

        init(with iName: String, date iDate: Date?) {
            name = iName
            date = iDate ?? Date()
        }

        init(with string: String) {
            let    parts = string.components(separatedBy: kColonSeparator)
            name         = parts[0]
            let interval = parts[1]
            
            if  let    i = Double(interval) {
                date     = Date(timeIntervalSince1970: i)
            }
        }
        
    }

	var zDeleted = [ZDeleted]()
    @objc dynamic var deleted: [String]?
	override var cloudProperties: [String] { return ZManifest.cloudProperties }
	override class var cloudProperties: [String] { return super.cloudProperties + [#keyPath(deleted)] }
	override func ignoreKeyPathsForStorage() -> [String] { return super.ignoreKeyPathsForStorage() + [#keyPath(deleted)] }
	convenience init(databaseID: ZDatabaseID?) { self.init(record: CKRecord(recordType: kManifestType), databaseID: databaseID) }

    var updatedRefs: [String]? {
        if  let d = deleted {                 // FIRST: merge deleted into zDeleted
            for ref in d {
                smartAppend(ref)
            }
        }

        let zCount = zDeleted.count
        let dCount = deleted?.count ?? 0

        if  zCount > 0, zCount != dCount {    // SECOND: update deleted if count does not match zDeleted
            deleted = []
            
            // create deleted from zDeleted
            for zd in zDeleted {
                if  let s = zd.string {
                    deleted?.append(s)
                }
            }
        }

        return deleted
    }

    func apply() {
        for deleteMe in zDeleted {
            if  let      name = deleteMe.name,
                let      dbID = databaseID {
                let   records = gRemoteStorage.cloud(for: dbID)
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
        var date       = zd?.date ?? zRecord?.record?.creationDate

        if  let     s  = refString {
            zd         = ZDeleted(with: s)
            name       = zd?.name
            date       = zd?.date
        }

        if  let     n  = name {
            for ref in zDeleted {
                if  n == ref.name {
                    return false // already there, do not add (a duplicate)
                }
            }
            
            if  zd == nil {
                zd  = ZDeleted(with: n, date: date)
            }
            
            zDeleted.append(zd!)
            needSave()
            
            return true
        }

        return false
    }

    convenience init(dict: ZStorageDictionary, in dbID: ZDatabaseID) throws {
        self.init(record: nil, databaseID: dbID)

		try extractFromStorageDictionary(dict, of: kManifestType, into: dbID)
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
