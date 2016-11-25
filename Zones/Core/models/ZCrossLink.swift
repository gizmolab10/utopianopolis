//
//  ZCrossLink.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZCrossLink: NSObject {


    dynamic var crossReference: CKReference?
    var                 ckzone: ZCloudZone?
    var      resolvedReference: ZRecord?


    func resolvedObject(_ onResolution: ObjectClosure) {
        onResolution(self.resolvedReference!)
    }


}
