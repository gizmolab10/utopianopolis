//
//  ZManifest.swift
//  Zones
//
//  Created by Jonathan Sand on 3/24/19.
//  Copyright © 2019 Zones. All rights reserved.
//


import Foundation
import CloudKit


var gManifest: ZManifest? { return gCloud?.manifest }


class ZManifest: ZRecord {
    
    
    @objc dynamic var deletedRefs: [CKRecord.Reference]?


    func apply() {
        
    }
    
    
    func smartAppend(_ iItem: AnyObject) {
        if  deletedRefs == nil {
            deletedRefs = [CKRecord.Reference]()
        }
        
        var reference   = iItem as? CKRecord.Reference
        
        if  let zRecord = iItem as? ZRecord {
            reference   = zRecord.record?.reference
        }

        if  reference != nil {
            deletedRefs?.append(reference!)
            needSave()
        }
    }

    
    class func cloudProperties() -> [String] {
        return[#keyPath(deletedRefs)]
    }
    
    
    override func cloudProperties() -> [String] {
        return super.cloudProperties() + ZManifest.cloudProperties()
    }
    

    convenience init(databaseID: ZDatabaseID?) {
        self.init(record: CKRecord(recordType: kManifestType), databaseID: databaseID)
    }
    
    
    convenience init(dict: ZStorageDictionary, in dbID: ZDatabaseID) {
        self.init(record: nil, databaseID: dbID)
        
        setStorageDictionary(dict, of: kManifestType, into: dbID)
    }
    

    override func setStorageDictionary(_ dict: ZStorageDictionary, of iRecordType: String, into iDatabaseID: ZDatabaseID) {
        super.setStorageDictionary(dict, of: iRecordType, into: iDatabaseID)
        
        if  let deletedsArray = dict[.deleted] as? [ZStorageDictionary] {
            for deletedDict: ZStorageDictionary in deletedsArray {
                if let deleted = CKRecord.Reference.create(with: deletedDict, for: iDatabaseID) {
                    cloud?.temporarilyIgnoreAllNeeds() { // prevent needsSave caused by child's parent (intentionally) not being in childDict
                        gManifest?.smartAppend(deleted)
                    }
                }
            }
        }
    }
    
    
    override func storageDictionary(for iDatabaseID: ZDatabaseID, includeRecordName: Bool = true) -> ZStorageDictionary? {
        var dict              = super.storageDictionary(for: iDatabaseID, includeRecordName: includeRecordName) ?? ZStorageDictionary ()
        
        if  let deletedsArray = ZManifest.storageArray(for: deletedRefs, from: iDatabaseID, includeRecordName: includeRecordName) {
            dict[.deleted]    = deletedsArray as NSObject?
        }
        
        return dict
    }

}
