//
//  Zone.swift
//  Zones
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


let zoneNameKey = "zoneName"
let childrenKey = "children"


class Zone : ZBase {

    
    dynamic var zoneName: String?
    var            links: [String : [Zone]] = [:]
    var         children: [Zone] = []


    convenience init(dict: ZStorageDict) {
        self.init(record: nil, database: modelManager.currentDB)

        storageDict = dict
    }


    override init(record: CKRecord?, database: CKDatabase) {
        super.init(record: record, database: database)
    }


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + [#keyPath(zoneName), #keyPath(links)]
    }


    override func updateProperties() {
        if record != nil {
            if record[zoneNameKey] != nil {
                zoneName = record[zoneNameKey] as? String
            }
        }
    }


    override func setStorageDictionary(_ dict: ZStorageDict) {
        zoneName = dict[zoneNameKey] as? String

        if let childrenStore: [ZStorageDict] = dict[childrenKey] as! [ZStorageDict]? {
            for child: ZStorageDict in childrenStore {
                let zone = Zone.init(dict: child)

                children.append(zone)
            }
        }

        super.setStorageDictionary(dict) // do this step last so the assignment above is NOT pushed into iCloud
    }


    override func storageDictionary() -> ZStorageDict? {
        var dict: ZStorageDict = super.storageDictionary()!
        dict[zoneNameKey]      = zoneName as NSObject?

        var childrenStore: [ZStorageDict] = []

        for child: Zone in children {
            childrenStore.append(child.storageDictionary()!)
        }

        dict[childrenKey]      = childrenStore as NSObject?

        return dict
    }
}
