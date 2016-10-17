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
    dynamic var    zones: [String : NSObject] = [:]
    var         children: [Zone] = []



    override func propertyKeyPaths() -> [String] {
        return super.propertyKeyPaths() + [#keyPath(zoneName), #keyPath(children)]
    }


    override func updateProperties() {
        if record != nil {
            zoneName = record["zoneName"] as? String
        }
    }


    override func setStorageDictionary(_ dict: [String : NSObject]) {
        zoneName = dict["zoneName"] as? String

        super.setStorageDictionary(dict) // do this step last so the assignment above is NOT pushed into iCloud
    }


    override func storageDictionary() -> [String : NSObject]? {
        var dict: [String : NSObject] = super.storageDictionary()!
        dict["zoneName"]              = zoneName as NSObject?

        return dict
    }
}
