//
//  ZManifest.swift
//  Zones
//
//  Created by Jonathan Sand on 3/24/19.
//  Copyright © 2019 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZManifest: ZRecord {
    
    
    @objc dynamic var deletedRefs: [CKRecord.Reference]?


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
    

    func apply() {
        
    }
    
    
    func smartAppend(reference: CKRecord.Reference) {
        
    }
}
