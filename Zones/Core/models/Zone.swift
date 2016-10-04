//
//  Zone.swift
//  Zones
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class Zone : ZBase {

    dynamic var zoneName: String?
    dynamic var actions: NSSet?
    dynamic var backlinks: NSSet?
    dynamic var links: NSSet?
    dynamic var traits: NSSet?


    override init(record: CKRecord, database: CKDatabase) {
        super.init(record: record, database: database)
        self.zoneName = record["zoneName"] as? String
    }


    override func propertyKeyPaths() -> [String] {
        return super.propertyKeyPaths() + [#keyPath(zoneName), #keyPath(actions), #keyPath(backlinks), #keyPath(links), #keyPath(traits)]
    }
}
