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
}
