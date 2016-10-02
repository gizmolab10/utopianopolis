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

    var zoneName: String?
    var actions: NSSet?
    var backlinks: NSSet?
    var links: NSSet?
    var traits: NSSet?


    override init(record: CKRecord, database: CKDatabase) {
        super.init(record: record, database: database)
        self.zoneName = record["zoneName"] as? String
    }


}
