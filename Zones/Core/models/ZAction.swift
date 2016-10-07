//
//  ZAction.swift
//  Zones
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZAction: ZBase {

    var action: NSDictionary?
    var  owner: Zone?


    override func propertyKeyPaths() -> [String] {
        return super.propertyKeyPaths() + [#keyPath(action), #keyPath(owner)]
    }
}
