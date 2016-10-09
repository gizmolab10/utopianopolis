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


    override func propertyKeyPaths() -> [String] {
        return super.propertyKeyPaths() + [#keyPath(zoneName), #keyPath(zones)]
    }


    override func updateProperties() {
        self.zoneName = self.record["zoneName"] as? String
    }


    override func setStorageDictionary(_ dict: [String : NSObject]) {
        for key: String in dict.keys {
            switch key {
            case "zoneName":
                self.zoneName = dict[key] as! String?
                break
            default:
                break
            }
        }
    }


    override func storageDictionary() -> [String : NSObject]? {
        var dict: [String : NSObject] = [:]

        for path in propertyKeyPaths() {
            switch path {
            case "zoneName":
                dict[path] = self.zoneName as NSObject?
                break
            default:
                break
            }
        }

        return dict
    }
}
