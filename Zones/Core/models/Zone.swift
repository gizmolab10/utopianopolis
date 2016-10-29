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
    var         children: [Zone] = []
    var            links: [String : [Zone]] = [:]
    var     showChildren: Bool = true

    var parent: Zone? {
        get {
            if record != nil {
                if let parents: [Zone] = links[parentsKey] {

                    return parents[0]
                }
            }

            return nil
        }
    }


    convenience init(dict: ZStorageDict) {
        self.init(record: nil, database: cloudManager.currentDB)

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
        if let string = dict[    zoneNameKey] as!   String? { zoneName     = string }
        if let number = dict[showChildrenKey] as! NSNumber? { showChildren = number.boolValue }

        if let childrenStore: [ZStorageDict] = dict[childrenKey] as! [ZStorageDict]? {
            for child: ZStorageDict in childrenStore {
                let               zone = Zone.init(dict: child)
                zone.links[parentsKey] = [self]

                children.append(zone)
            }
        }

        super.setStorageDictionary(dict) // do this step last so the assignment above is NOT pushed into iCloud
    }


    override func storageDictionary() -> ZStorageDict? {
        var dict: ZStorageDict = super.storageDictionary()!
        dict[zoneNameKey]      = zoneName as NSObject?
        dict[showChildrenKey]  = NSNumber(booleanLiteral: showChildren)

        var childrenStore: [ZStorageDict] = []

        for child: Zone in children {
            childrenStore.append(child.storageDictionary()!)
        }

        dict[childrenKey]      = childrenStore as NSObject?

        return dict
    }
}
