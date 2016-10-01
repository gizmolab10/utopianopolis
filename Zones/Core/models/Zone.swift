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

    var record: CKRecord!
    weak var database: CKDatabase!
    var zoneName: String?
    var actions: NSSet?
    var backlinks: NSSet?
    var links: NSSet?
    var traits: NSSet?


    init(record: CKRecord, database: CKDatabase) {
        self.record = record
        self.database = database
        self.zoneName = record["zoneName"] as? String
    }


}
