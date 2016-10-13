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
        self.zoneName = self.record["zoneName"] as? String
    }


    override func setStorageDictionary(_ dict: [String : NSObject]) {
        self.zoneName = dict["zoneName"] as? String

        super.setStorageDictionary(dict) // do last so above "change" is not pushed into iCloud
    }


    override func storageDictionary() -> [String : NSObject]? {
        var dict: [String : NSObject] = super.storageDictionary()!
        dict["zoneName"]              = self.zoneName as NSObject?

        return dict
    }
}
