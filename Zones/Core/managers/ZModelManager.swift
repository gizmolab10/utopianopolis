//
//  ZModelManager.swift
//  Zones
//
//  Created by Jonathan Sand on 9/18/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


protocol ZModelManagerDelegate {
    func errorUpdating(_ error: NSError)
    func modelUpdated()
}


class ZModelManager {
    let container: CKContainer
    let  publicDB: CKDatabase
    let privateDB: CKDatabase

    init() {
        container = CKContainer.default()
        privateDB = container.privateCloudDatabase
        publicDB  = container.publicCloudDatabase
    }
}
