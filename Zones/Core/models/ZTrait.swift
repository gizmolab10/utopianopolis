//
//  ZTrait.swift
//  Zones
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZTrait: ZBase {

    var   key: String?
    var  type: String?
    var value: Data?
    var owner: Zone?


    override func propertyKeyPaths() -> [String] {
        return super.propertyKeyPaths() + [#keyPath(key), #keyPath(type), #keyPath(value), #keyPath(owner)]
    }
}
